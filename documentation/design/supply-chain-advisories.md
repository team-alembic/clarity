# Design: Supply-Chain Advisories in the Security Lens

Status: Draft · 2026-06-30 · extends [security-lens.md](security-lens.md)

## Goal

Surface known vulnerabilities in a project's dependencies as first-class graph
data, overlaid on the dependency graph Clarity already draws. The motivating
incident: `mdex`/`mdex_native` CVEs that CI's `audit` step caught. Under the
security lens, Clarity should show the vulnerable dependency highlighted in the
graph and the path by which it's pulled in — *before* CI does, and in the same
tool the developer is already exploring.

This is **not** a re-skin of `mix deps.audit`. A flat CVE list adds nothing over
the CLI. Clarity's only differentiated contribution is the graph: advisories as
navigable vertices, and dependency-path / blast-radius via the `:dependency`
edges that already exist.

## Privacy principle (non-negotiable)

**The dependency list never leaves the machine.** Clarity downloads the *public*
advisory database in bulk and matches locally. It never transmits dependency
coordinates to a third-party query API. The only egress is fetching a static,
public file that reveals nothing about the project.

## Data sources

Both are bulk public downloads, matched locally — the dependency list never
leaves the machine.

- **osv.dev bulk export** (vulnerabilities) — the per-ecosystem archive
  `https://osv-vulnerabilities.storage.googleapis.com/Hex/all.zip` (ecosystem
  `Hex`; exact path to confirm). OSV-schema JSON for the whole Hex ecosystem.
- **EEF coverage** — EEF-curated Elixir/Erlang advisories are mirrored into
  osv.dev's `Hex` ecosystem, so the bulk download subsumes EEF. (Verify the
  overlap; don't query EEF separately unless a gap is found.)
- **Hex registry** (retirement + outdated) — the bulk registry (the `/versions`
  resource, and the per-package resource if the retired flag/reason isn't in the
  bulk one — fetched wholesale, never per-dependency) gives each package's
  versions, retired flags, and latest version. Decoded with `hex_core`. This
  covers retirement and "behind latest" without per-dependency egress.

Retirement and outdatedness are **dependency-hygiene** signals, distinct from
vulnerabilities — modelled as status on the Application vertex, not as advisory
vertices (see below).

## Architecture

Four pieces, all within Clarity's existing extension model and OTP structure.

### 1. Fetcher (`Clarity.Advisory.Source` — GenServer)

- Supervised in Clarity's tree; refreshes on a timer (default daily).
- Downloads both bulk sources, parses them (OSV JSON; Hex registry via
  `hex_core`), and persists to a **DETS table** under the existing `:cache_path`
  — the tzdata approach: a refresh rewrites the table, reads come from it (with
  an ETS read-through for matching). A restart is warm; an offline start serves
  the last persisted data.
- Records `last_refreshed_at`, and an "attempted" flag so a failing/offline
  fetch settles (empty results) rather than blocking the graph forever.
- The fetcher does **not** kickstart introspection (that would defeat
  `auto_start?: false`). The advisory listing reads the source live, so it's
  always current; advisory *vertices* refresh on the next introspection.
  Triggering a live rebuild on refresh is deferred (Phase 3).

### 2. `Clarity.Vertex.Advisory` (vertex type)

Fields: `id` (e.g. `GHSA-…`/`CVE-…`), `summary`, `severity`, affected package +
version ranges, `references`, `aliases`. Implements the `Clarity.Vertex`
protocol; `name/1` = the advisory id, `type_label/1` = "Advisory".

### 3. Advisory introspector (`Clarity.Introspector.Advisory`)

- `source_vertex_types/0` → `[Vertex.Application]`.
- For each Application vertex, matches its `name` + `version` against the cached
  OSV entries (see Matching). For each hit, emits `{:vertex, advisory}` and
  `{:edge, application, advisory, :advisory}`.
- Reads the fetcher's cache, so it is intentionally non-deterministic on cache
  freshness — a documented departure from the "pure analysis of loaded code"
  norm. Returns `{:error, :unmet_dependencies}` when the cache is not yet
  populated, so it retries after the first fetch.

### 4. Content + lens

- A content provider under the **existing `security` lens**, applying to
  Application and Advisory vertices:
  - **Application** → its advisories (severity, summary, fixed-in version); its
    **dependency-hygiene status** (retired — with reason where available — and
    "behind latest"); and the **dependency path** back to the project's own
    app(s) via `:dependency` edges (the blast-radius view).
  - **Advisory** → full detail and the affected apps.
  - **Domain/app roll-up** → counts and a list of vulnerable/retired dependencies.
- The security lens gains Application + Advisory in its `show_vertex_types`, so
  vulnerable nodes are visible when navigating the dependency graph.

Retirement/outdated are status on the Application vertex, not vertices of their
own. Being hygiene rather than vulnerability signals, they may also deserve
visibility outside the security lens (e.g. a general dependency/health view) —
flagged as an open question, not assumed.

## Matching

Each OSV entry's `affected[]` carries `package.name` (ecosystem `Hex`) plus
either explicit `versions[]` or `ranges[]` of `introduced`/`fixed` events. A
dependency `(name, version)` matches when the name matches and the version is
`>= introduced and < fixed` for some range (or is in `versions[]`). Use Elixir's
`Version` module for comparison.

## Configuration

```elixir
config :clarity, :advisories,
  enabled?: true,          # off => fully offline, no fetch, no advisory vertices
  refresh_interval: :timer.hours(24),
  source_url: "https://osv-vulnerabilities.storage.googleapis.com/Hex/all.zip"
```

`enabled?` must allow air-gapped/offline environments to opt out entirely.

## Graceful degradation

Offline, firewalled, or rate-limited is a normal state, never an error: the lens
shows the last cached data (or "advisory data unavailable / never fetched"),
always annotated with `last_refreshed_at` so findings carry their own freshness.
A failed fetch never breaks a render or the graph.

## Limitations (state these in the UI)

- The graph is the **OTP application graph** (built from loaded apps'
  `applications` lists), not the exact mix dependency tree. It won't see
  build-only or unloaded deps, and the dependency path is the OTP-app path.
- Findings are only as fresh as the last successful fetch.
- Vulnerability presence ≠ exploitability — the vulnerable code may not be
  reached. Report as "dependency has a known advisory," not "you are vulnerable."
- Retirement/outdated are not covered in the first cut.

## Phasing

1. **(done)** Fetcher + DETS cache (osv source) + `Advisory` vertex +
   introspector + Application/Advisory content. Validated end to end against
   live osv.dev data (`mdex` 0.13.1 → EEF-CVE-2026-53426/-54889).
2. Hex registry source → retirement + outdated status on Application content.
3. Dependency-path / blast-radius view, domain/app roll-up, and live rebuild on
   refresh.

## Decisions

- **Enabled by default** (`enabled?: true`); air-gapped users opt out. The egress
  is only public static files.
- **DETS cache**, tzdata-style: refresh rewrites the table, reads come from it.
- **Retirement/outdated are in scope**, sourced from the bulk Hex registry (no
  per-dependency egress), modelled as Application status distinct from advisories.

## Open questions

- Exact osv.dev bulk path / `Hex` ecosystem naming, and whether the Hex retired
  flag/reason is in the bulk `versions` resource or the per-package resource —
  confirm at implementation.
- Whether dependency-hygiene status (retired/outdated) should also surface
  outside the security lens, given it's tangential to vulnerabilities.
