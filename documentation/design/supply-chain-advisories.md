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

## Data source

- **osv.dev bulk export** — the per-ecosystem archive
  `https://osv-vulnerabilities.storage.googleapis.com/Hex/all.zip` (ecosystem
  name `Hex`; exact path to be confirmed at implementation). A zip of OSV-schema
  JSON entries covering the whole Hex ecosystem.
- **EEF coverage** — the Elixir/Erlang advisories the EEF Security WG curates are
  published into the GitHub Advisory DB and mirrored into osv.dev's `Hex`
  ecosystem, so the single bulk download subsumes EEF. (Verify the overlap; do
  not query EEF separately unless a gap is found.)
- **Retirement / outdated (deferred)** — Hex package retirement and
  latest-version are *not* in osv. They'd require per-package Hex queries, which
  reintroduces the egress concern, so they're out of scope for the first cut and
  revisited as a separate, opt-in follow-up.

## Architecture

Four pieces, all within Clarity's existing extension model and OTP structure.

### 1. Advisory fetcher (`Clarity.Advisory.Source` — GenServer)

- Supervised in Clarity's tree; refreshes on a timer (default daily).
- Downloads the bulk export, unpacks and parses the OSV entries, and writes them
  to disk under the existing `:cache_path` (so a restart is warm and an offline
  start still has data), plus an in-memory/ETS copy for matching.
- Records a `last_refreshed_at` timestamp.
- On a successful refresh that changes the data, triggers an incremental graph
  rebuild (the same mechanism code-reload already uses).

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
  - **Application** → its advisories (severity, summary, fixed-in version), and
    the **dependency path** back to the project's own app(s) — plain traversal
    of `:dependency` edges, the blast-radius view.
  - **Advisory** → full detail and the affected apps.
  - **Domain/app roll-up** → counts and a list of vulnerable dependencies.
- The security lens gains Application + Advisory in its `show_vertex_types`, so
  vulnerable nodes are visible when navigating the dependency graph.

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

1. Fetcher + on-disk cache + `Advisory` vertex + introspector + Application/
   Advisory content (advisory listing). Proves the pipeline end to end.
2. Dependency-path / blast-radius view and the domain/app roll-up.
3. Retirement / outdated (revisits the per-package egress decision; likely
   opt-in).

## Open questions

- Exact osv.dev bulk path and `Hex` ecosystem naming — confirm at implementation.
- `enabled?` default — on (fetch on first boot) or off (explicit opt-in)? Leaning
  on, since the egress is only a public static file, but air-gap users need the
  off switch regardless.
- Cache format on disk — raw OSV JSON vs a pre-indexed term keyed by package.
