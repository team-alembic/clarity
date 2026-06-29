# Design: Make the Security Lens Answer a Question

Status: Draft · 2026-06-29 · spike on `spike/security-lens`

## Problem

Clarity renders an entity graph and a set of per-vertex content tabs. For
anyone who can read code, the current content competes with reading the source
and loses — it restates declarations that are already in the file. The tool
answers "what exists", which is the one question a developer rarely has.

Two pieces of evidence from the current code:

1. **Content providers are entity-renderers.** Every `*Overview` provider takes
   a vertex and dumps its declared properties as markdown tables
   (`ResourceOverview` → attributes/relationships/actions/aggregates/calculations,
   straight from `Ash.Resource.Info`). No new information over the source.

2. **The lens is plumbed everywhere and used nowhere.** Every content provider
   receives the active `%Lens{}` in `applies?/2` and `render_static/2`, and all
   eleven ignore it (`_lens` in every clause; zero `lens.` references in any
   body). The "filtered views for different audiences" promise is fully wired
   and completely inert — a security reviewer and an architect see byte-identical
   content for the same vertex.

The three shipped lenses (Architect, Security, Debug) compound this: their
`filter/1` functions are near-identical (Architect's and Security's are the same
code), and they differ only in a hardcoded `show_vertex_types/1` allowlist. The
Security lens encodes no security knowledge — it's a type filter wearing a 🛡️.

## Thesis

A lens should change **what the content says**, not just which vertex types
appear in navigation. The bar Clarity must clear is showing something the code
doesn't. In an Ash application a large amount of the truth is *emergent* —
composed across policies, actions, attributes, and relationships at compile
time — and is therefore not readable from any single file. That emergent,
multi-file truth is the defensible core of the product.

The Security lens is the sharpest wedge to prove this: the data is rich, the
lens plumbing already exists, and "who can do what, and what's unprotected" is a
question even the author of an Ash resource cannot answer by reading one file.

## Design principles

- **Findings, not verdicts.** Surface a fact plus why it might matter, never
  "you have a vulnerability". Ash has legitimate reasons for every pattern
  (public reference data, deliberately open internal tools). Cry wolf once and
  the lens gets ignored.
- **Beat grep.** Only surface what reading the source can't give you cheaply:
  cross-referenced coverage, effective outcomes, transitive reachability.
- **Reuse the wired interface.** The lens argument is already threaded into
  every provider. Lens-aware content is filling in a built-but-inert interface,
  not new machinery.

## Findings catalogue

Each finding lists where it surfaces and the introspection source. Everything
except the cross-resource finding is computable from data Clarity already pulls.

### Domain / Application — the posture dashboard (entry point)

| Finding | Source |
| --- | --- |
| Authorisation mode: `:by_default` / `:when_requested` / `:always`; actor required? | `Ash.Domain.Info.authorize/1`, `require_actor?/1` |
| Resources with no `Ash.Policy.Authorizer` (count + list) | `Ash.Resource.Info.authorizers/1` per resource |
| Resources carrying bypass policies | `Ash.Policy.Info.policies/1` → `policy.bypass?` |

`:when_requested` is the highest-leverage finding in the tool: policies only run
when the caller passes `authorize?: true`, and that is invisible in any resource
file.

### Resource

| Finding | Source |
| --- | --- |
| Authorizer present? If not: "no policy enforcement — every action allowed (subject to domain mode)" | `Ash.Resource.Info.authorizers/1` |
| **Action coverage matrix**: per action, which policies govern it and the effective outcome | `Ash.Resource.Info.actions/1` × `Ash.Policy.Info.policies/1` |
| Field exposure: public **and** sensitive attributes; whether a field policy covers them | `Ash.Resource.Info.attributes/1`, `Ash.Policy.Info.field_policies_for_field/2` |

The coverage matrix is the finding that justifies the work — it requires
cross-referencing policies against actions, which is exactly the emergent value.

The matrix has two columns from two analyses:

**Governed by** — syntactic condition resolution (`PolicyAnalysis.coverage/2`),
using only statically decidable condition checks: `Ash.Policy.Check.Static`
(`always`/`never` via `result:`), `ActionType` (`type:`), `Action` (`action:`).
Anything else is reported as a runtime condition, never guessed.

**Reachable** — a completeness check via **Ash's own SAT solver**
(`PolicyAnalysis.action_verdict/2`). Rather than re-implement policy semantics,
we build an `%Ash.Policy.Authorizer{}` for the action and call
`Ash.Policy.Checker.strict_check_all_facts/1` + `strict_check_scenarios/1`, which
reduce the policies to a boolean formula and solve it with `picosat_elixir`
(already in the dep tree). Verdicts:

- `:unrestricted` — no policy authorizer
- `:always` — authorisation is a tautology (open to any actor)
- `:never` — no scenario authorises the actor (admin/bypass-only, or a gap)
- `:conditional` — depends on runtime checks (e.g. row filters)

**Actor profiles.** Ash's `strict_check` resolves actor-*attribute* checks
against the concrete actor, so the verdict is always relative to *which* actor
we solve for. Rather than one synthetic actor, the matrix has a column per
actor profile (`PolicyAnalysis.actor_profiles/1`); the **delta between columns**
is the finding (e.g. anonymous→user = "auth required"; user→api-key = "is the
key scoped down?").

Profiles come from `config :clarity, :security_actors` (a `label => spec` map),
or, unconfigured, from AshAuthentication installer conventions:

- `"Anonymous"` → `nil`
- `"User"` → `<App>.Accounts.User` struct (defaults = unprivileged user)
- `"API key"` → the user struct tagged `__metadata__.using_api_key?` (the
  api-key actor in AshAuthentication is the user, flagged via metadata), when
  `<App>.Accounts.ApiKey` is present

Within a profile, filter checks like `id == actor(:id)` defer to `:unknown`
(free variables → `:conditional`), while attribute checks like
`actor_attribute_equals(:admin, true)` resolve against the actor's defaults
(→ `:never`, i.e. admin/bypass-only). On the demo this proves reads need
authentication (anonymous `Never` → user `Conditional`) and all writes are
admin-only (`Never` for both shipped profiles).

**Limits.** The solver treats each check as an opaque boolean plus the
relationships Ash encodes (action-type exclusivity, negation). It reasons about
*structural* completeness — tautology, contradiction, unreachability — not the
*semantics* of filter expressions, so it will not detect a filter that leaks
rows. It also couples Clarity to Ash internals (`Checker`/`Authorizer`), taken
on deliberately for the spike with no fallback.

### Policy (replaces the static evaluation note)

`PolicyOverview` currently ends with a generic paragraph about how Ash evaluates
policies. Replace it with the computed trace for *this* policy:

| Finding | Source |
| --- | --- |
| Which actions this policy's condition governs | condition checks (as above) |
| Effectively-open flag: any `authorize_if always()` | `policy.policies` → check type + module |
| Bypass reach: "if this passes, remaining policies are skipped" | `policy.bypass?` |

### Cross-resource (Phase 2 — the thing only Clarity can do)

> "`Account` has strict policies, but is reachable via the public `:transactions`
> relationship from `Ledger`, which has no authorizer."

Walk relationship edges in the `:digraph`; correlate authorizer/policy state
across the path. No file contains this — it is the product of policy state on
two resources plus an edge between them. Needs new graph traversal, hence
Phase 2.

## Phasing

1. **Single-resource analysis (done).** A lens-aware `SecurityOverview`
   provider over Domain + Resource vertices. Reuses existing introspection;
   proves the lens-changes-content thesis cheaply.
2. **Policy-level computed trace (done).** `PolicyOverview` is lens-aware: under
   the Security lens it replaces the generic evaluation note with the actions
   this policy governs (resolved via `Clarity.Ash.PolicyAnalysis`, extracted as
   the shared resolver's second caller) and flags `authorize_if always()`.
2.5. **SAT completeness check (done).** The resource action matrix's
   **Reachable** column is solved by Ash's SAT solver
   (`PolicyAnalysis.action_verdict/2`) rather than the syntactic resolver — see
   the resource findings above.
3. **Cross-resource reachability.** New digraph traversal over relationship
   edges.

## Spike scope (`spike/security-lens`)

One new content provider, `Clarity.Content.Ash.SecurityOverview`, registered in
`mix.exs`:

- `applies?/2` returns true only for `%Lens{id: "security"}` on Domain and
  Resource vertices — so the tab appears *only* under the Security lens,
  demonstrating the lens controlling content.
- Domain vertex → posture roll-up.
- Resource vertex → authorisation posture, action coverage matrix, field
  exposure.

Demonstrable against the existing demo `Demo.Accounts.User`, which surfaces:

- **Writes are admin-only.** The only non-bypass policy is `action_type(:read)`;
  `create`/`update`/`update2`/`destroy` are governed solely by the
  `bypass always()` admin check → forbidden by default for non-admins. Not
  obvious from reading the file.
- **`date_of_birth` is public *and* sensitive** with no field policy → exposed.
- **`api_key` is sensitive but private** → correctly protected (shown as a
  non-finding for contrast).

## Risks / open questions

- **Condition resolution accuracy.** The static resolver covers the common
  checks; anything else must degrade to "conditional (runtime)" rather than
  claim coverage. Over-claiming here is the fastest way to lose trust.
- **False positives on field exposure.** `public? + sensitive?` is a strong
  signal but not always a bug. Phrase as exposure, not defect.
- **Lens as a struct match.** The spike matches `%Lens{id: "security"}`
  directly. If lens identity should be more structured than a string id, that's
  a small refactor — flagged, not assumed.
- **Where does posture roll-up belong** — a new tab, or folded into the existing
  domain overview under the lens? Spike uses a separate tab for clarity of demo.
