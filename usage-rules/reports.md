# Creating Reports

Reports are **written roll-ups** of the graph: a single document that sums up
part of the graph in one place, an alternative to navigating it vertex by
vertex. A report is **action-first**: it says how many things there are to do,
lists them most severe first, each with what it affects and the fix, and keeps
the reference data below in closed sections. It doesn't explain itself up
front; anything worth explaining goes in a hover hint. For users who want the
relevant information in one place (e.g. a "Supply chain security" or "Security
posture" report), a report gathers the relevant vertices and says what to do
about them.

Reports are a top-level section, not part of any lens: the activity bar down
the left edge shows an icon per lens and, below them, **Reports**, so no report
is hidden behind a lens choice. Reports opens `Clarity.ReportLive` at
`prefix/reports`, whose sidebar lists every registered report as a tree,
grouped by category, and which shows the selected one at
`prefix/reports/:report_id` under its name and description.

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
- A report renders with `Clarity.Report.Components`: a `status/1` line, a
  `todo_list/1` of `todo/1`s (with `group/1` rows, `chip/1`s, `more/1` for
  long lists and a `command/1` to copy), and closed `section/1`s holding
  `.report-table`s. Descriptions and other free text from the code go through
  `<.markdown>`; pass one `Clarity.Autolink.index/2` as `index` when there are
  many.
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
`name_style`. Work out the findings there, and render them with
`Clarity.Report.Components` (wrapped in a single root element, as a stateful
LiveComponent requires):

```elixir
alias Clarity.Report.Components

@impl Phoenix.LiveComponent
def update(assigns, socket) do
  unlicensed = unlicensed_resources(assigns.graph)

  {:ok,
   assign(socket,
     prefix: assigns.prefix,
     lens: assigns.lens,
     unlicensed: unlicensed,
     todos: Enum.count([unlicensed], &(&1 != []))
   )}
end

@impl Phoenix.LiveComponent
def render(assigns) do
  ~H"""
  <section class="space-y-6">
    <Components.status count={@todos} />

    <Components.todo_list :if={@todos > 0}>
      <Components.todo
        severity={:medium}
        title="Resources without a licence"
        count={length(@unlicensed)}
        hint="Why it matters, in a sentence, on hover."
      >
        <Components.chip
          :for={resource <- @unlicensed}
          patch={Components.path(@prefix, @lens, Vertex.id(resource))}
        >
          {Vertex.name(resource)}
        </Components.chip>
        <:fix>Add a <code>licence</code> to each.</:fix>
      </Components.todo>
    </Components.todo_list>

    <Components.section id="resources" title="Every resource">
      <table class="report-table">...</table>
    </Components.section>
  </section>
  """
end
```

Lead with what to do, not with what the report is: no introduction, a
one-line fix per to-do, a command to copy where one fixes it, and the full data
in closed sections. `Clarity.Report.SupplyChain`,
`Clarity.Report.SecurityPosture` and `Clarity.Report.Ontology` are worked
examples.

HEEx escapes text from outside the codebase, such as an advisory's summary, so
render it as text rather than through `<.markdown>`.

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

assert html =~ "Resources without a licence"
```

For the end-to-end routes, drive `Clarity.ReportLive` with
`Phoenix.LiveViewTest.live/2` against `/reports/:report_id` (see
`test/clarity/pages/report_live_test.exs`).

## Real-World Examples

- `lib/clarity/report/supply_chain.ex` — the dependencies to update:
  advisories, then retired and outdated versions, each with the
  `mix deps.update` to copy.
- `lib/clarity/report/security_posture.ex` — what to fix in how resources are
  protected: sensitive fields, policies, anonymous reach and bypasses, with who
  can reach what below (Ash-guarded; analysed asynchronously, and rendered
  through a `posture/1` function component that tests can call directly).
- `lib/clarity/report/ontology.ex` — the documentation to write, then the
  domain vocabulary: entities and their terms (attributes, calculations,
  aggregates, relationships), descriptions linked from one autolink index
  (Ash-guarded).

## Next Steps

1. Test the report renders the right roll-up for a hand-built graph.
2. Register it, then check it appears in the Reports sidebar under its category.
