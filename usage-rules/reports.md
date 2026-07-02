# Creating Reports

Reports are **lens-scoped roll-ups** of the graph, rendered as a single
interactive view — an alternative to navigating the graph vertex by vertex. For
users who want all the relevant information in one place (e.g. a "Supply chain
security" or "Security posture" report), a report gathers the relevant vertices
and presents them together.

The navigation header shows an **Explore | Reports** toggle whenever the active
lens has at least one report; `Clarity.ReportLive` renders the lens's reports as
a picker and embeds the selected one.

## When to Create a Report

Create a report when a lens's story is best told as one document rather than by
drilling into individual vertices — a cross-cutting summary that rolls up many
vertices. If you're adding a view for a *single* vertex, use a
[content provider](content-providers.md) instead.

## How Reports Work

- A report declares its `name/0`, an optional `description/0`, and which lens it
  `applies?/1` to.
- The module is also a **LiveComponent** (`use Clarity.Web, :live_component`), so
  it can be interactive (filter, sort, expand). `ReportLive` embeds it and passes
  `graph`, `lens`, and `prefix` assigns.
- The report queries the graph itself — typically
  `Clarity.Graph.vertices(graph, {:==, :vertex_type, SomeVertex})` — and reuses
  the per-vertex analysis (status providers, `Clarity.Ash.PolicyAnalysis`, etc.).
- Rows link back into the graph with a `patch` to
  `Path.join([prefix, lens.id, Clarity.Vertex.id(vertex)])`.

Reports are registered per-application under `:clarity_reports` and discovered
via `Clarity.Config.list_reports/0`.

## Step-by-Step Guide

### 1. Create the Report Module

```elixir
defmodule MyApp.Report.Compliance do
  @moduledoc "Compliance roll-up across resources."

  @behaviour Clarity.Report
  use Clarity.Web, :live_component

  alias Clarity.Graph
  alias Clarity.Perspective.Lens
  alias Clarity.Vertex
end
```

### 2. Implement the `Clarity.Report` Callbacks

```elixir
@impl Clarity.Report
def name, do: "Compliance"

@impl Clarity.Report
def description, do: "Licence and policy compliance across resources"

@impl Clarity.Report
def applies?(%Lens{id: "security"}), do: true
def applies?(_lens), do: false
```

### 3. Implement the LiveComponent

`update/2` receives `graph`, `lens`, and `prefix`. Build the report data there,
then render (and handle events for interactivity):

```elixir
@impl Phoenix.LiveComponent
def update(assigns, socket) do
  rows =
    assigns.graph
    |> Graph.vertices({:==, :vertex_type, Vertex.Ash.Resource})
    |> Enum.map(&build_row/1)

  {:ok, assign(socket, prefix: assigns.prefix, lens: assigns.lens, rows: rows)}
end

@impl Phoenix.LiveComponent
def render(assigns) do
  ~H"""
  <section>
    <h2>Compliance</h2>
    <table>
      <tr :for={row <- @rows}>
        <td>
          <.link patch={Path.join([@prefix, @lens.id, Vertex.id(row.vertex)])}>
            {row.name}
          </.link>
        </td>
      </tr>
    </table>
  </section>
  """
end
```

For interactivity (filter/sort), keep the choice in the socket and re-derive the
visible rows in `render/1`, with `phx-target={@myself}` on the controls — see
`Clarity.Report.SupplyChain` for a worked example.

### 4. Register the Report

```elixir
# In config/config.exs or config/runtime.exs
config :my_app, :clarity_reports, [
  MyApp.Report.Compliance
]
```

> **Shipping a report from a library?** Register it in your library's
> `application/0` environment instead, guarded with
> `Code.ensure_loaded?(Clarity.Report)`. See
> [Integrating a Library with Clarity](../documentation/how_to/integrate-from-a-library.md).

## Lens Scoping

`applies?/1` decides which lenses offer the report. The Explore | Reports toggle
only appears when `Clarity.Report.applicable(lens)` is non-empty, so a report
that applies to no active lens is simply never shown.

## Reusing Existing Analysis

A report is mostly composition. Reuse what already computes per-vertex facts:

- **Supply-chain**: `Clarity.Status.SupplyChain.statuses/2`,
  `Clarity.Advisory.Source.advisories_for/2`,
  `Clarity.Dependency.Registry.summary/1`.
- **Ash posture**: `Clarity.Ash.PolicyAnalysis` (`coverage/2`, `actor_profiles/1`,
  `action_verdict/3`) and `Ash.Resource.Info` / `Ash.Policy.Info`.

## Testing Reports

Test the component in isolation with `render_component/2` (it runs `update/2` +
`render/1`), passing a hand-built graph, a lens, and a prefix:

```elixir
html =
  render_component(MyApp.Report.Compliance,
    id: "report",
    graph: graph,
    lens: Clarity.Perspective.Lensmaker.Security.make_lens(),
    prefix: "/clarity"
  )

assert html =~ "Compliance"
```

For the end-to-end route + toggle, drive `Clarity.ReportLive` with
`Phoenix.LiveViewTest.live/2` against the report path (see
`test/clarity/pages/report_live_test.exs`).

## Real-World Examples

- `lib/clarity/report/supply_chain.ex` — filter chips + sortable table.
- `lib/clarity/report/security_posture.ex` — per-resource enforcement/exposure
  roll-up (Ash-guarded).

## Next Steps

1. Test the report renders the right roll-up for a lens.
2. Confirm `applies?/1` scopes it to the intended lens(es).
3. Verify the Explore | Reports toggle appears and rows link into the graph.
