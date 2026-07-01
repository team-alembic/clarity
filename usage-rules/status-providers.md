# Creating Status Providers

Status providers flag vertices with `info` / `warning` / `error` indicators.
Clarity rolls those indicators up the navigation tree, so a collapsed subtree
surfaces the most severe status buried inside it, with a count of how many of its
descendants are flagged.

## When to Create a Status Provider

Create one when you want to draw attention to a condition on a vertex that a
developer should notice while navigating — for example an outdated dependency, a
resource with no authorization policies, a module with compile warnings, or a
non-compliant licence. If you only need to *show* information when a vertex is
selected, use a [content provider](content-providers.md) instead; a status
provider is for the at-a-glance flag in the tree.

## How Status Indicators Work

A status flows through five stages:

1. **Producer** — your provider returns `Clarity.Status` structs for a vertex.
2. **Class** — each status carries a semantic `class` (e.g. `:security`,
   `:hygiene`) decoupled from the producing module.
3. **Lens filter** — a lens surfaces only the classes it cares about via its
   `status_filter` (see [lensmakers](lensmakers.md)). By default a lens surfaces
   nothing, so indicators are opt-in per lens.
4. **Roll-up** — `Clarity.Status.Index` aggregates the surviving statuses up the
   tree: each vertex's entry carries the worst severity in its subtree and a
   count of flagged vertices (including itself).
5. **Render** — the navigation tree draws a severity-coloured badge.

Your job is only stage 1; the rest is handled for you.

## Step-by-Step Guide

### 1. Create the Status Provider Module

```elixir
defmodule MyApp.LicenceStatus do
  @moduledoc "Flags dependencies with a non-compliant licence."

  @behaviour Clarity.Status.Provider

  alias Clarity.Status
  alias Clarity.Vertex
end
```

### 2. Implement `statuses/2`

`statuses/2` receives a vertex and the graph and returns a list of
`Clarity.Status` structs. Return `[]` for vertices the provider has nothing to
say about — match the vertex types you care about and let a catch-all clause
return nothing:

```elixir
@impl Clarity.Status.Provider
def statuses(%Vertex.Application{} = vertex, _graph) do
  case licence(vertex) do
    {:ok, :compliant} ->
      []

    {:ok, :non_compliant} ->
      [
        %Status{
          severity: :warning,
          class: :licence,
          message: "Non-compliant licence",
          source: __MODULE__
        }
      ]
  end
end

def statuses(_vertex, _graph), do: []
```

A vertex may carry more than one status (e.g. a security *and* a hygiene
finding) — return them all.

### 3. Register the Status Provider

```elixir
# In config/config.exs or config/runtime.exs
config :my_app, :clarity_status_providers, [
  MyApp.LicenceStatus
]
```

> **Shipping a status provider from a library?** Register it in your library's
> `application/0` environment instead, guarded with
> `Code.ensure_loaded?(Clarity.Status.Provider)`. See
> [Integrating a Library with Clarity](../documentation/how_to/integrate-from-a-library.md)
> for the full pattern.

## The Status Struct

```elixir
%Clarity.Status{
  severity: :info | :warning | :error,
  class: atom(),
  message: String.t(),
  source: module()
}
```

- **`severity`** — ordered `info < warning < error`. The roll-up keeps the worst
  severity in a subtree. Helpers: `Clarity.Status.rank/1`,
  `Clarity.Status.max_severity/2`.
- **`class`** — the semantic domain the status belongs to (`:security`,
  `:hygiene`, `:licence`, …). Lenses filter on `class`, so a lens can surface
  your domain without knowing your module exists.
- **`message`** — a short human-readable description.
- **`source`** — the producing module (set it to `__MODULE__`). Used for
  provenance and de-duplication, **not** for filtering.

### Choosing a severity

| Severity | Use for |
| --- | --- |
| `:info` | Worth knowing, not urgent (e.g. a newer version exists) |
| `:warning` | Should be addressed (e.g. retired/deprecated, missing policy) |
| `:error` | Needs attention now (e.g. a known security advisory) |

### Choosing a class

Pick a coarse, shared domain rather than a per-provider name — multiple providers
can contribute to one class, and a lens surfaces a class regardless of which
provider produced it. Clarity ships `:security` (vulnerabilities) and `:hygiene`
(outdated/retired dependencies).

## Surfacing Statuses in a Lens

Indicators are opt-in. A lens shows none unless its `status_filter` accepts them.
To surface your class, set the lens's `status_filter` (in a lensmaker):

```elixir
%Lens{
  # ...
  status_filter: &(&1.class in [:security, :hygiene, :licence])
}
```

See [Creating Lensmakers](lensmakers.md) for the full lens API.

## Roll-up Behaviour

You produce statuses per vertex; `Clarity.Status.Index` does the aggregation:

- A vertex's badge reflects the **worst severity** anywhere in its subtree.
- The **count** is the number of flagged vertices in the subtree, **including the
  vertex itself**.
- The walk covers the whole tree, not just expanded nodes, so a collapsed parent
  still flags what's beneath it.
- Only statuses the active lens surfaces are counted.

You don't call the index yourself — just return accurate per-vertex statuses.

## Flagging the Tab That Explains a Status

A content provider can declare the status classes it explains via the optional
`status_classes/0` callback (see [content providers](content-providers.md)). When
the selected vertex carries a surfaced status of that class, the content's tab is
flagged with a severity dot — so a developer who lands on a flagged node can see
which tab explains it. For example `Clarity.Content.Dependency` returns
`[:hygiene]` and `Clarity.Content.Advisory` returns `[:security]`. Match the
classes your provider produces to the content that explains them.

## Testing Status Providers

Test `statuses/2` directly with hand-built vertices and a graph:

```elixir
defmodule MyApp.LicenceStatusTest do
  use ExUnit.Case, async: true

  alias Clarity.Graph
  alias Clarity.Status
  alias MyApp.LicenceStatus
  alias Clarity.Vertex

  test "flags a non-compliant dependency" do
    graph = Graph.new()
    vertex = %Vertex.Application{app: :baddep, description: "Bad", version: "1.0.0"}

    assert [%Status{severity: :warning, class: :licence}] =
             LicenceStatus.statuses(vertex, graph)
  end

  test "returns nothing for unrelated vertices" do
    assert LicenceStatus.statuses(%Vertex.Root{}, Graph.new()) == []
  end
end
```

The roll-up itself is covered by `Clarity.Status.Index`'s own tests, so you only
need to test that your provider returns the right statuses.

## Common Pitfalls

### Filtering on `source` instead of `class`

Lenses filter on `class`. If you reuse another provider's class, your statuses
will surface wherever that class does — usually what you want. Invent a new class
only when it's a genuinely different domain a lens might surface independently.

### Raising in `statuses/2`

A provider that raises is isolated (logged and treated as no statuses) so it
can't break the tree — but don't rely on that. Return `[]` for the cases you
don't handle rather than letting a `case` blow up.

### Expensive work per vertex

`statuses/2` runs for every vertex in the tree on each tree update. Keep it cheap
— read from already-computed data (graph edges, a cache/ETS table) rather than
doing I/O or heavy computation per call.

## Real-World Example

See `lib/clarity/status/supply_chain.ex` — `Clarity.Status.SupplyChain` flags
applications with `:security`/`:error` for advisories, `:hygiene`/`:warning` for
retired versions, and `:hygiene`/`:info` for outdated ones, reading advisory
edges from the graph and version data from the Hex registry.

## Next Steps

After creating a status provider:

1. Test that it returns the right statuses for relevant and irrelevant vertices.
2. Set a lens's `status_filter` to surface your class.
3. Verify the badges and roll-up counts appear as expected in the tree.
