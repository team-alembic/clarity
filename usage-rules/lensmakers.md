# Creating Lensmakers

Lensmakers create "lenses" that provide filtered views of the graph
for different audiences. A lens can filter vertices, customize
content display, and provide a tailored perspective on the codebase.

## When to Create a Lensmaker

Create a lensmaker when you want to:

- Provide a specialized view for a specific audience (e.g.,
  security team, new developers, auditors)
- Filter the graph to show only relevant information
- Customize content ordering for specific use cases
- Enhance existing lenses with additional functionality

## Lensmaker Types

### Base Lensmaker

Creates a new lens from scratch by implementing `make_lens/0`.

### Extension Lensmaker

Enhances existing lenses by implementing `update_lens/1`. This
allows you to modify lenses created by other libraries or modules.

## Step-by-Step Guide: Creating a Base Lens

### 1. Create the Lensmaker Module

```elixir
defmodule MyApp.SecurityLensmaker do
  @moduledoc """
  Creates a security-focused lens for auditing.
  """

  @behaviour Clarity.Perspective.Lensmaker

  import Phoenix.Component

  alias Clarity.Graph.Filter
  alias Clarity.Perspective.Lens
  alias Clarity.Vertex
end
```

### 2. Implement `make_lens/0`

Return a `Lens` struct with required fields:

```elixir
@impl Clarity.Perspective.Lensmaker
def make_lens do
  %Lens{
    id: "security",
    name: "Security Audit",
    description: "Security-related vertices and relationships",
    icon: &icon/0,
    filter: security_filter()
  }
end

defp icon do
  assigns = %{}
  ~H"🛡️"
end

defp security_filter do
  Filter.vertex_type([
    Vertex.Ash.Policy,
    Vertex.Ash.Action
  ])
end
```

### 3. Register the Lensmaker

```elixir
# In config/config.exs or config/runtime.exs
config :my_app, :clarity_perspective_lensmakers, [
  MyApp.SecurityLensmaker
]
```

## Lens Struct Fields

### Required Fields

- **`id`** (String) - Unique identifier for the lens
  - Must be unique across all lenses
  - Use lowercase with underscores: `"my_lens"`

- **`name`** (String) - Display name shown in UI
  - Should be short and descriptive: `"Security Audit"`

- **`icon`** (Function) - Icon function returning HEEx
  - Must return `Phoenix.LiveView.Rendered.t()`
  - Use Phoenix.Component for rendering

- **`filter`** (Filter) - Graph filter query
  - Can be a static filter or a function
  - Uses `Clarity.Graph.Filter` helpers

### Optional Fields

- **`description`** (String | nil) - Detailed description
  - Used in tooltips or help text
  - Can be `nil`

- **`content_sorter`** (Function) - Content sorting function
  - Signature: `(Content.t(), Content.t() -> boolean())`
  - Default: alphabetical with Graph last

- **`show_vertex_types`** (Function) - Vertex type filter
  - Signature: `([module()] -> [module()])`
  - Default: show all types

## Filter Patterns

### Static Filters

Use filter queries directly:

```elixir
# Single vertex type
filter: {:==, :vertex_type, Vertex.Application}

# Multiple vertex types
filter: {:in, :vertex_type,
  [Vertex.Module, Vertex.Application]}

# Using Filter helpers
filter: Filter.vertex_type([Vertex.Ash.Resource])
```

### Dynamic Filters

Use a function that receives the graph:

```elixir
filter: fn graph ->
  # Calculate interesting vertices dynamically
  important_modules = find_important_modules(graph)

  {:in, :vertex_id,
    Enum.map(important_modules, &Clarity.Vertex.id/1)}
end
```

### Distance-Based Filters

Show vertices within a certain distance:

```elixir
filter: fn graph ->
  root = Clarity.Graph.get_vertex_by_type!(graph,
                                            Vertex.Root)
  Filter.within_steps(root, 2, 1)
end
```

### Reachability Filters

Show vertices reachable from specific points:

```elixir
filter: fn graph ->
  entry_points = find_entry_points(graph)
  Filter.reachable_from(entry_points)
end
```

## Icon Functions

Icons must be functions returning HEEx:

```elixir
# Simple emoji icon
defp icon do
  assigns = %{}
  ~H"🔍"
end

# Inline SVG icon
defp icon do
  assigns = %{}
  ~H"""
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20"
       fill="currentColor" class="w-5 h-5">
    <path fill-rule="evenodd"
          d="M9 3.5a5.5 5.5 0 100 11 5.5 5.5 0 000-11zM2
             9a7 7 0 1112.452 4.391l3.328 3.329a.75.75 0
             11-1.06 1.06l-3.329-3.328A7 7 0 012 9z"
          clip-rule="evenodd" />
  </svg>
  """
end
```

**Important:** Icon functions take no arguments and must create
their own assigns map.

## Content Sorting

Customize the order of content tabs:

```elixir
@impl Clarity.Perspective.Lensmaker
def make_lens do
  %Lens{
    # ... other fields ...
    content_sorter: &sort_content/2
  }
end

defp sort_content(a, b) do
  # Prioritize overview content
  case {a.name, b.name} do
    {"Overview", _} -> true
    {_, "Overview"} -> false
    # Then alphabetical
    _ -> a.name <= b.name
  end
end
```

**Default behavior:** Alphabetical, with Graph content last.

## Vertex Type Filtering

Control which vertex types are shown in the sidebar:

```elixir
@impl Clarity.Perspective.Lensmaker
def make_lens do
  %Lens{
    # ... other fields ...
    show_vertex_types: &filter_types/1
  }
end

defp filter_types(types) do
  # Only show resources and domains
  Enum.filter(types, fn type ->
    type in [
      Clarity.Vertex.Ash.Resource,
      Clarity.Vertex.Ash.Domain
    ]
  end)
end
```

**Default behavior:** Shows all vertex types.

## Step-by-Step Guide: Extension Lensmaker

### 1. Create Extension Module

```elixir
defmodule MyApp.SecurityExtension do
  @moduledoc """
  Enhances the security lens with custom content sorting.
  """

  @behaviour Clarity.Perspective.Lensmaker

  alias Clarity.Perspective.Lens
end
```

### 2. Implement `update_lens/1`

Modify lenses by ID:

```elixir
@impl Clarity.Perspective.Lensmaker
def update_lens(%Lens{id: "security"} = lens) do
  # Enhance the security lens
  %{lens | content_sorter: &security_content_sort/2}
end

def update_lens(lens) do
  # Pass through other lenses unchanged
  lens
end

defp security_content_sort(a, b) do
  # Custom sorting for security content
  priority_order = ["Policies", "Actions", "Overview"]

  case {Enum.find_index(priority_order, &(&1 == a.name)),
        Enum.find_index(priority_order, &(&1 == b.name))} do
    {nil, nil} -> a.name <= b.name
    {nil, _} -> false
    {_, nil} -> true
    {idx_a, idx_b} -> idx_a <= idx_b
  end
end
```

### 3. Register the Extension

```elixir
config :my_app, :clarity_perspective_lensmakers, [
  MyApp.SecurityLensmaker,      # Creates the lens
  MyApp.SecurityExtension       # Enhances it
]
```

## Two-Phase Lens Creation

Clarity creates lenses in two phases:

1. **Creation Phase** - Calls `make_lens/0` on implementing modules
2. **Enhancement Phase** - Calls `update_lens/1` on ALL lensmakers
   for each lens

This allows extensions to enhance base lenses from other libraries.

```elixir
# Phase 1: BaseLib creates "security" lens
defmodule BaseLib.SecurityLens do
  @impl Clarity.Perspective.Lensmaker
  def make_lens do
    %Lens{id: "security", ...}
  end
end

# Phase 2: Your extension enhances it
defmodule MyApp.SecurityExtension do
  @impl Clarity.Perspective.Lensmaker
  def update_lens(%Lens{id: "security"} = lens) do
    %{lens | description: "Enhanced security view"}
  end

  def update_lens(lens), do: lens
end
```

## Complete Examples

### Basic Audience Lens

```elixir
defmodule MyApp.DeveloperLensmaker do
  @behaviour Clarity.Perspective.Lensmaker

  import Phoenix.Component

  alias Clarity.Graph.Filter
  alias Clarity.Perspective.Lens
  alias Clarity.Vertex

  @impl Clarity.Perspective.Lensmaker
  def make_lens do
    %Lens{
      id: "developer",
      name: "Developer View",
      description: "Focus on code structure and modules",
      icon: &icon/0,
      filter: Filter.vertex_type([
        Vertex.Module,
        Vertex.Application
      ])
    }
  end

  defp icon do
    assigns = %{}
    ~H"👨‍💻"
  end
end
```

### Advanced Lens with Custom Filtering

```elixir
defmodule MyApp.AshResourcesLensmaker do
  @behaviour Clarity.Perspective.Lensmaker

  import Phoenix.Component

  alias Clarity.Graph
  alias Clarity.Graph.Filter
  alias Clarity.Perspective.Lens
  alias Clarity.Vertex

  @impl Clarity.Perspective.Lensmaker
  def make_lens do
    %Lens{
      id: "ash_resources",
      name: "Ash Resources",
      description: "Complete view of Ash resources",
      icon: &icon/0,
      filter: &ash_filter/1,
      content_sorter: &content_sort/2,
      show_vertex_types: &show_types/1
    }
  end

  defp icon do
    assigns = %{}
    ~H"🔥"
  end

  defp ash_filter(graph) do
    # Find all resource vertices
    resource_ids =
      graph
      |> Graph.list_vertices()
      |> Enum.filter(&match?(%Vertex.Ash.Resource{}, &1))
      |> Enum.map(&Clarity.Vertex.id/1)

    # Show resources and things reachable from them
    resource_vertices =
      Enum.map(resource_ids, fn id ->
        Graph.get_vertex!(graph, id)
      end)

    Filter.reachable_from(resource_vertices)
  end

  defp content_sort(a, b) do
    # Prioritize resource overview
    case {a.name, b.name} do
      {"Resource Overview", _} -> true
      {_, "Resource Overview"} -> false
      {"Actions", _} -> true
      {_, "Actions"} -> false
      _ -> a.name <= b.name
    end
  end

  defp show_types(types) do
    # Only show Ash-related types
    Enum.filter(types, fn type ->
      module_string = to_string(type)
      String.contains?(module_string, "Ash")
    end)
  end
end
```

### Extension Pattern

```elixir
defmodule MyApp.LensEnhancements do
  @behaviour Clarity.Perspective.Lensmaker

  alias Clarity.Perspective.Lens

  # Enhance multiple lenses
  @impl Clarity.Perspective.Lensmaker
  def update_lens(%Lens{id: "debug"} = lens) do
    %{lens | description: "Enhanced debug view"}
  end

  def update_lens(%Lens{id: "security"} = lens) do
    %{lens | show_vertex_types: &security_types/1}
  end

  def update_lens(lens), do: lens

  defp security_types(types) do
    # Add custom security-related types
    custom_types = [MyApp.Vertex.SecurityCheck]
    Enum.uniq(types ++ custom_types)
  end
end
```

## Testing Lensmakers

```elixir
defmodule MyApp.DeveloperLensmakerTest do
  use ExUnit.Case, async: true

  alias MyApp.DeveloperLensmaker
  alias Clarity.Perspective.Lens

  test "creates lens with correct properties" do
    assert %Lens{} = lens = DeveloperLensmaker.make_lens()
    assert lens.id == "developer"
    assert lens.name == "Developer View"
    assert is_function(lens.icon, 0)
    assert is_function(lens.filter) or is_tuple(lens.filter)
  end

  test "icon renders without errors" do
    lens = DeveloperLensmaker.make_lens()
    assert %Phoenix.LiveView.Rendered{} = lens.icon.()
  end
end
```

## Real-World Examples

See existing lensmakers in the Clarity codebase:

- **Simple**: `lib/clarity/perspective/lensmaker/debug.ex`
- **With Grouping**: Check Ash-related lensmakers

## Common Pitfalls

### Non-Unique Lens IDs

**Problem:** Multiple lenses with the same ID.

**Solution:** Use unique IDs with namespacing:

```elixir
# Bad - might conflict
id: "overview"

# Good - namespaced
id: "myapp_overview"
```

### Icon Function Without Assigns

**Problem:** Icon function crashes with "undefined assigns".

**Solution:** Always create assigns map in icon function:

```elixir
# Bad
defp icon, do: ~H"🔍"

# Good
defp icon do
  assigns = %{}
  ~H"🔍"
end
```

### Filter Functions Not Handling Empty Graph

**Problem:** Filter crashes on empty graph.

**Solution:** Handle edge cases:

```elixir
defp my_filter(graph) do
  case find_root(graph) do
    nil -> {:==, :vertex_id, "nonexistent"}
    root -> Filter.reachable_from([root])
  end
end
```

### Forgetting update_lens Catch-All

**Problem:** Extension crashes on unexpected lens IDs.

**Solution:** Always include catch-all clause:

```elixir
@impl Clarity.Perspective.Lensmaker
def update_lens(%Lens{id: "my_lens"} = lens) do
  enhance_lens(lens)
end

def update_lens(lens), do: lens  # Don't forget this!
```

## Performance Tips

- Keep filter functions fast
- Cache expensive computations
- Avoid traversing entire graph if possible
- Use Filter helpers for common patterns

## Next Steps

After creating a lensmaker:

1. Test with various graph sizes
2. Verify icon renders correctly
3. Ensure filter produces expected results
4. Consider creating content providers specific to your lens
5. Document the intended audience and use case
