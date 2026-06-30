# Design: Navigation-Tree Status Indicators

Status: Draft · 2026-07-01

## Goal

Flag vertices in the navigation tree with `info` / `warning` / `error`
indicators, and roll those up so a **collapsed** subtree surfaces the worst
problem buried inside it. First use: supply-chain — an outdated dependency shows
`info`, a retired one `warning`, one with a security advisory `error`.

The indicator vocabulary is general (not security-specific); supply-chain is
just the first producer.

## Decisions (agreed)

1. **`Status.Provider` extension point now** — a registered behaviour like
   content providers/introspectors. Supply-chain is the first implementation.
2. **Lens-controlled visibility, keyed on a status `class`** — each status
   carries a semantic `class` (`:security`, `:hygiene`, …). A lens declares the
   classes it surfaces and rolls up only those, ignoring other domains. Filtering
   on `class` (not the producer module) means any provider can contribute to a
   class without the lens knowing about it.
3. **Severity map**: `outdated → :info`, `retired → :warning`, `advisory → :error`.
4. **Roll-up badge shows worst severity + a count** of flagged descendants.

Likely **two classes** for supply-chain: `:security` (advisories) and `:hygiene`
(outdated/retired) — honouring the distinction the advisories design already
draws. The security lens declares `[:security, :hygiene]` for now; a future
maintenance/health lens could surface `:hygiene` alone. (Granularity still open
— see below.)

## Architecture

### 1. `Clarity.Status` (value)

```elixir
%Clarity.Status{
  severity: :info | :warning | :error,
  class: atom(),          # semantic domain, e.g. :security / :hygiene — drives lens roll-up
  message: String.t(),
  source: module()        # the producing module — provenance/tooltip/dedup, NOT filtering
}
```

Severity is ordered (`info < warning < error`); helpers `rank/1` and `max/2`.
`class` is what lenses filter on (decoupled from the producer); `source` is the
producing module, kept for provenance and tooltips but not used for filtering.

### 2. `Clarity.Status.Provider` (behaviour)

```elixir
@callback statuses(vertex :: Clarity.Vertex.t(), graph :: Clarity.Graph.t()) :: [Clarity.Status.t()]
```

Lens-agnostic: a provider returns *all* statuses for a vertex; the lens decides
what to show. Discovered like content providers — `Clarity.Config.list_status_providers/0`
reads `:clarity_status_providers` across applications (mirrors
`list_content_providers/0`). Clarity registers its own supply-chain provider.

### 3. `Clarity.Status.SupplyChain` (first provider)

For `Vertex.Application` vertices:
- `class: :security`, `:error` when the app has one or more `:advisory`
  out-edges in the graph (message names the count / ids).
- `class: :hygiene`, `:warning` when the installed version is in the Registry's
  `retired` list.
- `class: :hygiene`, `:info` when `Dependency.outdated?/2` against the
  Registry's latest.

Reuses the exact signals the security lensmaker already derives. Other vertex
types → `[]`.

### 4. Lens `status_filter`

Add one field to `Clarity.Perspective.Lens`:

```elixir
@type status_filter_fn() :: (Clarity.Status.t() -> boolean())
# struct default: fn _status -> false end   # opt-in: show nothing unless a lens enables it
```

A predicate keeps it flexible, but lenses filter primarily on `class`.
`Lensmaker.Security` sets `status_filter: &(&1.class in [:security, :hygiene])`.
The predicate is the escape hatch for finer rules (e.g. class plus a minimum
severity). Only statuses passing the filter are aggregated, so the roll-up
reflects the lens's domains.

### 5. Aggregation + the lazy-tree constraint

The nav tree is **lazy** — a collapsed node doesn't render its children, so its
rolled-up badge can't be derived from rendered descendants. Aggregation must be
**precomputed** over the full (lens-filtered) `tree_graph`:

```
status_index :: %{Vertex.id() => %{severity: severity(), count: non_neg_integer()}}
```

Post-order walk: each node's entry = max severity over {own filtered statuses} ∪
{children's entries}, and count = number of flagged vertices in the subtree
(including self). Built once per `(graph update_count, lens id, status epoch)`.

The **status epoch** matters: producer output depends on *external* data (the
advisory DB / Hex registry refresh), which doesn't bump the graph's
`update_count`. The cache key must include a refresh token so a registry/advisory
refresh re-rolls the indicators. First cut may simply recompute per tree update
(cheap: most vertices yield `[]` via fast ETS lookups) and add caching only if
measured to matter.

### 6. Rendering

In `render_node.html.heex`, next to `<.vertex_name>` (both the `<summary>` and
leaf branches): a badge driven by `status_index[Vertex.id(@vertex)]` —
`icon_info`/`icon_warning`/`icon_error` (already exist) coloured from the flash
palette (info=blue, warning=yellow, error=red), with the count when > 1, and a
tooltip (existing `Tooltip` hook) listing the reasons. No entry → no badge.

`status_index` is computed in `TreeComponent.update/2` (it has graph + lens) and
threaded through `render_vertex`/`render_node`.

## Phases

All phases implemented.

1. **(done)** `Clarity.Status` value + `Status.Provider` behaviour + `Config.list_status_providers/0` + register list.
2. **(done)** `Clarity.Status.SupplyChain` provider (advisory edges + Registry → severities).
3. **(done)** `Lens.status_filter` field (default off) + `Lensmaker.Security` opts in.
4. **(done)** Aggregation (`Clarity.Status.Index`, severity + count, post-order over the filtered tree).
5. **(done)** Rendering: soft tinted-pill badge in `render_node.html.heex`; `status_index` threaded through `TreeComponent`.
6. **(done)** Tests (provider, aggregation roll-up, lens filtering, render) + `usage-rules/status-providers.md`.

Deviation from plan: the badge ships as a severity-tinted pill (icon + count) with
a native `title`, rather than a hover tooltip listing per-status messages — the
roll-up entry carries only `{severity, count}`, and the detail lives in the
selected vertex's content. A richer tooltip would mean threading messages through
the index; deferred.

## Risks / unknowns

- **Performance**: aggregation is O(visible tree). Fine for supply-chain; revisit
  caching (epoch-keyed) if a large graph + many producers makes it slow. Measure
  before caching.
- **Cache invalidation on refresh**: tying the status epoch to advisory/registry
  refresh without over-invalidating. Deferred until caching is needed.
- **Provider error isolation**: a throwing/ slow provider mustn't break the tree
  render — wrap provider calls and drop failures (log once).
- **Visual noise**: badges on deep parents could clutter; the lens opt-in keeps
  them to the security lens initially.

## Resolved

- **Class granularity**: two classes — `:security` (advisories) and `:hygiene`
  (outdated/retired). The security lens surfaces both.
- **Default `status_filter`**: opt-in (off) everywhere except the security lens.
- **Count**: includes the vertex's own status (a flagged parent with two flagged
  children reads "3"), so it matches what you'd find by drilling in.
- **Leaf nodes**: icon only, no count (the count is only meaningful as a roll-up).
- **Class as data vs predicate**: predicate only for now (`&(&1.class in […])`);
  add a declarative `status_classes` later only if tooling needs to introspect it.
