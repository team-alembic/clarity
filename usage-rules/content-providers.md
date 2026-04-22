# Creating Content Providers

Content providers display information about vertices in the Clarity
UI. They can provide static content (markdown, mermaid, graphviz) or
implement full LiveView components for interactive functionality.

## When to Create a Content Provider

Create a content provider when you want to:

- Display custom documentation for your vertex types
- Show visualizations (diagrams, graphs, charts)
- Provide interactive exploration tools
- Generate formatted reports or summaries
- Display relationships and dependencies

## Content Provider Types

### Static Content

Static content is rendered once and doesn't change without a page
refresh. Types available:

- **`:markdown`** - GitHub-flavored markdown with support for
  `vertex://` links
- **`:mermaid`** - Mermaid diagrams (flowcharts, sequence diagrams,
  etc.)
- **`:viz`** - Graphviz DOT format for graph visualizations

### LiveView Content

LiveView content is fully interactive with real-time updates, event
handling, and dynamic state management.

## Step-by-Step Guide: Static Content

### 1. Create the Content Provider Module

```elixir
defmodule MyApp.Content.CustomAnalysis do
  @moduledoc """
  Displays custom analysis for MyApp entities.
  """

  @behaviour Clarity.Content

  alias Clarity.Vertex
end
```

### 2. Implement Required Callbacks

```elixir
@impl Clarity.Content
def name do
  "Custom Analysis"
end

@impl Clarity.Content
def description do
  "Provides custom analysis and metrics"
end

@impl Clarity.Content
def applies?(%MyApp.Vertex.CustomEntity{}, _lens) do
  true
end

def applies?(_vertex, _lens) do
  false
end
```

**Callbacks:**
- **`name/0`** - Tab name shown in the UI (required)
- **`description/0`** - Optional description for tooltips
- **`applies?/2`** - Whether to show for given vertex and lens
  (required)

### 3. Implement `render_static/2`

Return a tuple of `{type, content}`:

```elixir
@impl Clarity.Content
def render_static(vertex, _lens) do
  {:markdown, """
  # Analysis for #{vertex.name}

  **Type**: Custom Entity
  **Category**: #{vertex.category}

  ## Details

  This entity is defined in module
  [#{inspect(vertex.module)}](vertex://#{vertex_id(vertex.module)})
  """}
end

defp vertex_id(module) do
  Clarity.Vertex.Util.id(Clarity.Vertex.Module, [module, 0])
end
```

### 4. Register the Content Provider

```elixir
# In config/config.exs or config/runtime.exs
config :my_app, :clarity_content_providers, [
  MyApp.Content.CustomAnalysis
]
```

> **Shipping a content provider from a library?** Register it in
> your library's `application/0` environment instead, guarded with
> `Code.ensure_loaded?(Clarity.Content)`. See
> [Integrating a Library with Clarity](../documentation/how_to/integrate-from-a-library.md)
> for the full pattern.

## Static Content Examples

### Markdown Content

```elixir
@impl Clarity.Content
def render_static(vertex, _lens) do
  {:markdown, """
  # #{vertex.name}

  ## Overview
  #{vertex.description}

  ## Related Resources
  #{Enum.map_join(vertex.references, "\n", &format_link/1)}
  """}
end

defp format_link(ref_module) do
  id = Clarity.Vertex.Util.id(Clarity.Vertex.Module,
                                [ref_module, 0])
  "- [#{inspect(ref_module)}](vertex://#{id})"
end
```

### Mermaid Diagrams

```elixir
@impl Clarity.Content
def render_static(vertex, _lens) do
  {:mermaid, """
  flowchart TD
    A[#{vertex.name}] --> B[Process 1]
    A --> C[Process 2]
    B --> D[Output]
    C --> D
  """}
end
```

### Graphviz Visualizations

```elixir
@impl Clarity.Content
def render_static(vertex, _lens) do
  {:viz, """
  digraph G {
    node [shape=box];
    "#{vertex.name}" -> "Dependency 1";
    "#{vertex.name}" -> "Dependency 2";
  }
  """}
end
```

## Theme-Aware Content

Content can adapt to the current theme (light/dark):

```elixir
@impl Clarity.Content
def render_static(vertex, _lens) do
  {:viz, fn %{theme: theme} ->
    bg_color = if theme == :dark, do: "black", else: "white"
    fg_color = if theme == :dark, do: "white", else: "black"

    """
    digraph G {
      bgcolor="#{bg_color}";
      node [color="#{fg_color}" fontcolor="#{fg_color}"];
      edge [color="#{fg_color}"];
      "#{vertex.name}" -> "Other";
    }
    """
  end}
end
```

**Props available:**
- `theme`: `:light` or `:dark`
- `zoom_subgraph`: The filtered subgraph for the current lens

## Vertex Links

Use `vertex://` URLs to link to other vertices:

```elixir
@impl Clarity.Content
def render_static(vertex, _lens) do
  resource_id = Clarity.Vertex.Util.id(
    Clarity.Vertex.Ash.Resource,
    [vertex.resource]
  )

  {:markdown, """
  This action belongs to resource
  [#{vertex.resource}](vertex://#{resource_id})
  """}
end
```

**Format:** `vertex://<vertex-id>`

The vertex ID must match the ID returned by `Clarity.Vertex.id/1`
for the target vertex.

## Step-by-Step Guide: LiveView Content

### 1. Create LiveView Module

```elixir
defmodule MyApp.Content.InteractiveDashboard do
  use Phoenix.LiveView
  @behaviour Clarity.Content

  alias Clarity.Vertex
end
```

### 2. Implement Content Callbacks

```elixir
@impl Clarity.Content
def name, do: "Interactive Dashboard"

@impl Clarity.Content
def description, do: "Interactive exploration tool"

@impl Clarity.Content
def applies?(%MyApp.Vertex.CustomEntity{}, _lens), do: true
def applies?(_vertex, _lens), do: false
```

### 3. Implement LiveView Callbacks

```elixir
@impl Phoenix.LiveView
def mount(_params, session, socket) do
  vertex = session["vertex"]
  lens = session["lens"]

  {:ok, assign(socket,
    vertex: vertex,
    lens: lens,
    selected_tab: :overview
  )}
end

@impl Phoenix.LiveView
def render(assigns) do
  ~H"""
  <div class="dashboard">
    <h1>{@vertex.name}</h1>

    <div class="tabs">
      <button phx-click="select_tab" phx-value-tab="overview">
        Overview
      </button>
      <button phx-click="select_tab" phx-value-tab="details">
        Details
      </button>
    </div>

    <div class="content">
      <%= case @selected_tab do %>
        <% :overview -> %>
          <div>Overview content for {@vertex.name}</div>
        <% :details -> %>
          <div>Detailed information...</div>
      <% end %>
    </div>
  </div>
  """
end

@impl Phoenix.LiveView
def handle_event("select_tab", %{"tab" => tab}, socket) do
  {:noreply, assign(socket, selected_tab: String.to_atom(tab))}
end
```

**Session data provided:**
- `"vertex"` - The current vertex struct
- `"lens"` - The current lens struct

## Complete Examples

### Static Markdown Content

```elixir
defmodule MyApp.Content.EntityOverview do
  @behaviour Clarity.Content

  alias Clarity.Vertex
  alias MyApp.Vertex.CustomEntity

  @impl Clarity.Content
  def name, do: "Overview"

  @impl Clarity.Content
  def description, do: "Entity overview and summary"

  @impl Clarity.Content
  def applies?(%CustomEntity{}, _lens), do: true
  def applies?(_vertex, _lens), do: false

  @impl Clarity.Content
  def render_static(vertex, _lens) do
    {:markdown, """
    # #{vertex.name}

    **Type**: Custom Entity
    **Category**: #{vertex.category || "Uncategorized"}
    **Module**: `#{inspect(vertex.module)}`

    ## Configuration

    #{format_config(vertex)}

    ## Related Entities

    #{format_references(vertex)}
    """}
  end

  defp format_config(vertex) do
    case vertex.config do
      nil -> "_No configuration_"
      config ->
        config
        |> Enum.map(fn {k, v} -> "- **#{k}**: `#{inspect(v)}`" end)
        |> Enum.join("\n")
    end
  end

  defp format_references(vertex) do
    case vertex.references do
      [] -> "_No references_"
      refs ->
        refs
        |> Enum.map(&format_ref_link/1)
        |> Enum.join("\n")
    end
  end

  defp format_ref_link(ref_module) do
    id = Clarity.Vertex.Util.id(Vertex.Module, [ref_module, 0])
    "- [#{inspect(ref_module)}](vertex://#{id})"
  end
end
```

### Interactive LiveView Content

```elixir
defmodule MyApp.Content.EntityExplorer do
  use Phoenix.LiveView
  @behaviour Clarity.Content

  alias MyApp.Vertex.CustomEntity

  @impl Clarity.Content
  def name, do: "Explorer"

  @impl Clarity.Content
  def description, do: "Interactive entity explorer"

  @impl Clarity.Content
  def applies?(%CustomEntity{}, _lens), do: true
  def applies?(_vertex, _lens), do: false

  @impl Phoenix.LiveView
  def mount(_params, session, socket) do
    vertex = session["vertex"]

    {:ok, assign(socket,
      vertex: vertex,
      filter: "",
      selected: nil
    )}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="explorer">
      <h2>Exploring {@vertex.name}</h2>

      <input
        type="text"
        placeholder="Filter..."
        value={@filter}
        phx-change="filter"
        phx-debounce="300"
      />

      <div class="items">
        <%= for item <- filtered_items(@vertex, @filter) do %>
          <div
            class="item"
            phx-click="select"
            phx-value-id={item.id}
          >
            {item.name}
          </div>
        <% end %>
      </div>

      <%= if @selected do %>
        <div class="detail">
          Selected: {@selected.name}
        </div>
      <% end %>
    </div>
    """
  end

  @impl Phoenix.LiveView
  def handle_event("filter", %{"value" => filter}, socket) do
    {:noreply, assign(socket, filter: filter)}
  end

  @impl Phoenix.LiveView
  def handle_event("select", %{"id" => id}, socket) do
    items = socket.assigns.vertex.items
    selected = Enum.find(items, &(&1.id == id))
    {:noreply, assign(socket, selected: selected)}
  end

  defp filtered_items(vertex, filter) do
    vertex.items
    |> Enum.filter(fn item ->
      filter == "" or String.contains?(
        String.downcase(item.name),
        String.downcase(filter)
      )
    end)
  end
end
```

## Pattern: Conditional Content Based on Lens

Show different content based on the current lens:

```elixir
@impl Clarity.Content
def applies?(vertex, %Lens{id: "security"}) do
  # Only show for security lens
  has_security_info?(vertex)
end

def applies?(vertex, _lens) do
  # Show for all other lenses
  true
end
```

## Pattern: Multi-Format Content

Provide different formats based on complexity:

```elixir
@impl Clarity.Content
def render_static(vertex, lens) do
  if simple_view?(vertex, lens) do
    {:markdown, simple_summary(vertex)}
  else
    {:viz, complex_graph(vertex)}
  end
end
```

## Testing Content Providers

```elixir
defmodule MyApp.Content.EntityOverviewTest do
  use ExUnit.Case, async: true

  alias MyApp.Content.EntityOverview
  alias MyApp.Vertex.CustomEntity
  alias Clarity.Perspective.Lens

  setup do
    vertex = %CustomEntity{
      name: "test_entity",
      module: MyApp.Test,
      category: "test"
    }
    lens = %Lens{id: "default", name: "Default"}
    {:ok, vertex: vertex, lens: lens}
  end

  test "applies to CustomEntity vertices", %{vertex: vertex,
                                              lens: lens} do
    assert EntityOverview.applies?(vertex, lens)
  end

  test "returns name", do: assert EntityOverview.name() ==
    "Overview"

  test "renders markdown content", %{vertex: vertex,
                                      lens: lens} do
    assert {:markdown, content} =
      EntityOverview.render_static(vertex, lens)
    assert content =~ "test_entity"
    assert content =~ "Custom Entity"
  end
end
```

## Real-World Examples

See existing content providers in the Clarity codebase:

- **Simple Markdown**: `lib/clarity/content/moduledoc.ex`
- **Graph Viz**: `lib/clarity/content/graph.ex`
- **Ash Resource**: `lib/clarity/content/ash/resource_overview.ex`
- **LiveView**: `lib/clarity/content/ash/domain_overview.ex`
- **Phoenix Routes**: `lib/clarity/content/phoenix/router_routes.ex`

## Common Pitfalls

### Incorrect vertex:// Links

**Problem:** Links to other vertices don't work.

**Solution:** Ensure the vertex ID matches exactly what
`Clarity.Vertex.id/1` returns for that vertex:

```elixir
# Bad - guessing the ID
"[Link](vertex://module:my-module)"

# Good - using Util.id
id = Clarity.Vertex.Util.id(Vertex.Module, [MyModule, 0])
"[Link](vertex://#{id})"
```

### Missing @impl Annotations

**Problem:** Callbacks without `@impl` annotation.

**Solution:** Always use `@impl Clarity.Content`:

```elixir
@impl Clarity.Content
def name, do: "My Content"
```

### Theme-Unaware Graphviz

**Problem:** Graphviz content looks bad in dark mode.

**Solution:** Use a function that receives props with theme:

```elixir
# Bad - hard-coded colors
{:viz, "digraph { bgcolor=white; }"}

# Good - theme-aware
{:viz, fn %{theme: theme} ->
  bg = if theme == :dark, do: "black", else: "white"
  "digraph { bgcolor=#{bg}; }"
end}
```

### Expensive Computations in render_static

**Problem:** Slow content rendering.

**Solution:** Keep `render_static/2` fast. Pre-compute expensive
data in an introspector and store it in the vertex struct.

## Performance Tips

- Keep static content generation fast
- Avoid expensive computations in `applies?/2`
- Cache expensive lookups in LiveView state
- Use LiveView only when interactivity is needed
- Pre-compute complex data during introspection

## Next Steps

After creating content providers:

1. Test with different vertex types and lenses
2. Verify theme support works correctly
3. Ensure vertex:// links navigate properly
4. Consider creating multiple content providers for different views
   of the same data
