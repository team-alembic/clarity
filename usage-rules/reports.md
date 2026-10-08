# Creating Reports

Reports are **written roll-ups** of the graph: a single document that sums up
part of the graph in one place, an alternative to navigating it vertex by
vertex. A report is *prose*: it explains, in sentences, what's going on and why
it matters, rather than presenting a dashboard to operate. For users who want
the relevant information in one place (e.g. a "Supply chain security" or
"Security posture" report), a report gathers the relevant vertices and narrates
them.

Reports are a top-level section: the header shows **Explore** and **Reports**
under every lens, so no report is hidden behind a lens choice. Reports opens
`Clarity.ReportLive` at `prefix/:lens/reports`, which shows every registered
report as a tab and embeds the selected one at `prefix/:lens/reports/:report_id`.
The lens stays in the URL so Explore returns to it; it doesn't change which
reports are listed.

## When to Create a Report

Create a report when a story is best told as one document rather than by
drilling into individual vertices — a cross-cutting summary that rolls up many
vertices. If you're adding a view for a *single* vertex, use a
[content provider](content-providers.md) instead.

## How Reports Work

- A report declares its `name/0` and an optional `description/0`.
- The module is also a **LiveComponent** (`use Clarity.Web, :live_component`);
  `ReportLive` embeds it with these assigns:
  - `graph` - the whole graph, not filtered by any lens
  - `lens` - the current lens, for `<.markdown>`'s links
  - `prefix` - the URL prefix Clarity is mounted at
  - `version` - the graph's update count, which changes whenever introspection
    changes the graph; `update/2` then runs again, so the report stays current
- In practice a report builds a markdown string and renders it with
  `<.markdown>`, so it reads as prose.
- The report queries the graph itself, typically with
  `Clarity.Graph.vertices(graph, {:==, :vertex_type, SomeVertex})`, and reuses
  the per-vertex analysis (status providers, `Clarity.Ash.PolicyAnalysis`, etc.)
  to compose its narrative.

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
  alias Clarity.Vertex
end
```

### 2. Implement the `Clarity.Report` Callbacks

```elixir
@impl Clarity.Report
def name, do: "Compliance"

@impl Clarity.Report
def description, do: "Licence and policy compliance across resources"
```

### 3. Implement the LiveComponent

`update/2` receives `graph`, `lens`, `prefix` and `version`. Build the narrative
markdown there and render it with `<.markdown>` (wrapped in a single root
element, as a stateful LiveComponent requires):

```elixir
import Clarity.Components.MarkdownComponent

@impl Phoenix.LiveComponent
def update(assigns, socket) do
  {:ok,
   assign(socket,
     prefix: assigns.prefix,
     lens: assigns.lens,
     markdown: build_markdown(assigns.graph)
   )}
end

@impl Phoenix.LiveComponent
def render(assigns) do
  ~H"""
  <section>
    <.markdown content={@markdown} prefix={@prefix} lens={@lens} class="max-w-[75ch]" />
  </section>
  """
end

defp build_markdown(graph) do
  resources = Graph.vertices(graph, {:==, :vertex_type, Vertex.Ash.Resource})

  [
    "## Compliance\n\n",
    "This report reviews compliance across #{length(resources)} resources.\n\n",
    # ... narrative sections built from the analysis ...
  ]
end
```

Prefer prose — sentences and short sections that explain what's going on and why
it matters — over tables of raw data. `Clarity.Report.SupplyChain` and
`Clarity.Report.SecurityPosture` are worked examples.

Text from outside the codebase, such as an advisory's summary, goes into the
markdown as-is, so escape markdown in it before interpolating it.

If the analysis is slow (it grows with the app), run it with `assign_async/3` in
`update/2` and render it with `<.async_result>`, as `Clarity.Report.SecurityPosture`
does: the page shows at once, and the static render skips the work.

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
    lens: Clarity.Perspective.Lensmaker.Architect.make_lens(),
    prefix: "/clarity"
  )

assert html =~ "Compliance"
```

For the end-to-end routes, drive `Clarity.ReportLive` with
`Phoenix.LiveViewTest.live/2` against `/:lens/reports/:report_id` (see
`test/clarity/pages/report_live_test.exs`).

## Real-World Examples

- `lib/clarity/report/supply_chain.ex` — narrates advisories and dependency
  hygiene (retired/outdated) from the supply-chain status data.
- `lib/clarity/report/security_posture.ex` — narrates policy enforcement, bypass
  policies, and sensitive-field exposure across resources (Ash-guarded).

## Next Steps

1. Test the report renders the right roll-up for a hand-built graph.
2. Register it, then check it appears as a tab under Reports.
