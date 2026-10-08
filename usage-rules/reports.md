# Creating Reports

Reports are **written roll-ups** of the graph: a single document that sums up
part of the graph in one place, an alternative to navigating it vertex by
vertex. A report has two sides:

- **What there is to know**: the report itself, sections of tables and
  figures, open to scroll through. It doesn't explain itself up front;
  anything worth explaining goes in a hover hint.
- **What there is to do**: its *actions* (`actions/2`), each a kind of thing to
  do with the items it applies to — one to-do per item — most severe first,
  each with a one-line fix.

The activity bar down the left edge shows an icon per lens and, below them,
**Actions** and **Reports**, so nothing is hidden behind a lens choice. Both
open `Clarity.ReportLive`, whose sidebar lists the reports as a tree grouped by
category: Reports at `prefix/reports/:report_id` shows a report under its name
and description; Actions at `prefix/actions/:report_id` shows its to-dos. The
Actions icon, each category and each report under it carry a badge counting
the to-dos, tinted by the most severe, and each page's status line counts them
by severity.

## When to Create a Report

Create a report when a story is best told as one document rather than by
drilling into individual vertices — a cross-cutting summary that rolls up many
vertices. If you're adding a view for a *single* vertex, use a
[content provider](content-providers.md) instead.

## How Reports Work

- A report declares its `name/0`, an optional `description/0`, and an optional
  `category/0` that groups it in the Reports sidebar (reports without one sit
  below the categories). `ReportLive` shows the name and description as the
  page's title, so the component doesn't repeat them.
- The module is also a **LiveComponent** (`use Clarity.Web, :live_component`);
  `ReportLive` embeds it with these assigns:
  - `graph` - the whole graph, not filtered by any lens
  - `lens` - the default lens, for `<.markdown>`'s links
  - `prefix` - the URL prefix Clarity is mounted at
  - `version` - the graph's update count, which changes whenever introspection
    changes the graph; `update/2` then runs again, so the report stays current
  - `linking` - the viewer's text linking options from the settings menu (every
    mention, lowercase names); pass them on to `<.markdown>` along with `graph`
  - `name_style` - `:short` to name modules within what holds them where the
    report shows that (a resource beside its domain as `ApiKey`, a domain as
    `Accounts`), or `:qualified` in full
- A report renders with `Clarity.Report.Components`: `section/1`s holding
  `.report-table`s, with `chip/1`s for names. Descriptions and other free text
  from the code go through `<.markdown>`; pass one `Clarity.Autolink.index/2`
  as `index` when there are many.
- Its optional `actions/2` returns `Clarity.Report.Action`s (severity, title,
  hint, fix, an optional command to copy, and `groups` of `items`, each item
  linked to its vertex by `id`); `Clarity.Report.Components.actions/1` renders
  them. Clarity caches them per change to the graph
  (`Clarity.Report.Actions`), so the badges on every page don't rerun them.
  An optional `pending/1` says what the actions still wait for, e.g. a
  database download.
- The report queries the graph itself, typically with
  `Clarity.Graph.vertices(graph, {:==, :vertex_type, SomeVertex})`, and reuses
  the per-vertex analysis (status providers, `Clarity.Ash.PolicyAnalysis`, etc.)
  to work out its findings.

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

@impl Clarity.Report
def category, do: "Compliance"
```

### 3. Implement the LiveComponent

`update/2` receives `graph`, `lens`, `prefix`, `version`, `linking` and
`name_style`. Work out what there is to know there, and render it with
`Clarity.Report.Components` (wrapped in a single root element, as a stateful
LiveComponent requires):

```elixir
alias Clarity.Report.Components

@impl Phoenix.LiveComponent
def update(assigns, socket) do
  {:ok,
   assign(socket,
     prefix: assigns.prefix,
     lens: assigns.lens,
     resources: Graph.vertices(assigns.graph, {:==, :vertex_type, Vertex.Ash.Resource})
   )}
end

@impl Phoenix.LiveComponent
def render(assigns) do
  ~H"""
  <section class="space-y-6">
    <Components.section id="resources" title="Resources" count={length(@resources)}>
      <table class="report-table">...</table>
    </Components.section>
  </section>
  """
end
```

### 4. List What There Is to Do

Return the to-dos from `actions/2`, most severe first. Each item is one thing
to do, and counts as one in the badges:

```elixir
alias Clarity.Report.Action

@impl Clarity.Report
def actions(graph, _opts) do
  case unlicensed_resources(graph) do
    [] ->
      []

    resources ->
      [
        %Action{
          severity: :medium,
          title: "Resources without a licence",
          hint: "Why it matters, in a sentence, on hover.",
          fix: "Add a `licence` to each.",
          groups: [%{items: Enum.map(resources, &%{text: Vertex.name(&1), id: Vertex.id(&1)})}]
        }
      ]
  end
end
```

Lead with what to do, not with what the report is: no introduction, a
one-line fix per action (text between backticks is code), a `command` to copy
where one fixes it. `Clarity.Report.SupplyChain`,
`Clarity.Report.SecurityPosture` and `Clarity.Report.Ontology` are worked
examples.

HEEx escapes text from outside the codebase, such as an advisory's summary, so
render it as text rather than through `<.markdown>`.

If the analysis is slow (it grows with the app), run it with `assign_async/3` in
`update/2` and render it with `<.async_result>`, as `Clarity.Report.SecurityPosture`
does: the page shows at once, and the static render skips the work.

### 5. Register the Report

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

assert html =~ "Resources"
assert [%Clarity.Report.Action{title: "Resources without a licence"}] =
         MyApp.Report.Compliance.actions(graph, [])
```

For the end-to-end routes, drive `Clarity.ReportLive` with
`Phoenix.LiveViewTest.live/2` against `/reports/:report_id` (see
`test/clarity/pages/report_live_test.exs`).

## Real-World Examples

- `lib/clarity/report/supply_chain.ex` — every dependency with its version,
  the latest and its standing; its actions are the dependencies to update
  (advisories, then retired and outdated versions), each line with the
  `mix deps.update` to copy, and `pending/1` while the checks run.
- `lib/clarity/report/security_posture.ex` — who can reach what and each
  resource's posture; its actions are what to fix: sensitive fields, policies,
  anonymous reach and bypasses (Ash-guarded; analysed asynchronously, and
  rendered through a `posture/1` function component that tests can call
  directly).
- `lib/clarity/report/ontology.ex` — the domain vocabulary: entities and their
  terms (attributes, calculations, aggregates, relationships), descriptions
  linked from one autolink index; its actions are the documentation to write
  (Ash-guarded).

## Next Steps

1. Test the report renders the right roll-up, and `actions/2` the right
   to-dos, for a hand-built graph.
2. Register it, then check it appears in the Reports sidebar under its
   category, and under Actions with its badge.
