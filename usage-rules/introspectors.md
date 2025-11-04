# Creating Introspectors

Introspectors analyze the codebase and populate the graph with
vertices and edges. They process specific vertex types and return
new vertices/edges to add to the graph.

## When to Create an Introspector

Create a new introspector when you need to:

- Discover and analyze custom entities in your codebase
- Extract relationships between entities
- Process framework-specific structures (DSLs, configurations)
- Build graph structure from runtime or compile-time information

## Step-by-Step Guide

### 1. Define the Introspector Module

Create a module that implements the `Clarity.Introspector`
behavior:

```elixir
defmodule MyApp.MyCustomIntrospector do
  @moduledoc """
  Introspects custom entities and adds them to the graph.
  """

  @behaviour Clarity.Introspector

  alias Clarity.Graph
  alias Clarity.Vertex
end
```

### 2. Implement `source_vertex_types/0`

Specify which vertex types this introspector should process:

```elixir
@impl Clarity.Introspector
def source_vertex_types do
  [Vertex.Module]
end
```

This introspector will be called for every `Vertex.Module` in the
graph.

### 3. Implement `introspect_vertex/2`

Process each vertex and return entries to add to the graph:

```elixir
@impl Clarity.Introspector
def introspect_vertex(%Vertex.Module{module: module}, graph) do
  # Check if this module is interesting
  case Code.ensure_loaded(module) do
    {:module, ^module} ->
      if implements_custom_behaviour?(module) do
        process_module(module, graph)
      else
        {:ok, []}
      end
    _ ->
      {:ok, []}
  end
end

def introspect_vertex(_vertex, _graph) do
  {:ok, []}
end

defp process_module(module, graph) do
  custom_vertex = %MyApp.Vertex.CustomEntity{
    name: module_name(module),
    module: module
  }

  {:ok, [
    {:vertex, custom_vertex},
    {:edge, module_vertex(graph, module), custom_vertex,
     :defines}
  ]}
end

defp module_vertex(graph, module) do
  # Find the module vertex in the graph
  id = Clarity.Vertex.Util.id(Vertex.Module, [module, 0])
  Graph.get_vertex!(graph, id)
end
```

### 4. Register the Introspector

Add your introspector to the application configuration:

```elixir
# In config/config.exs or config/runtime.exs
config :my_app, :clarity_introspectors, [
  MyApp.MyCustomIntrospector
]
```

## Return Types

The `introspect_vertex/2` callback must return one of:

```elixir
# Success with entries to add
{:ok, [entry, ...]}

# Dependency not yet available, retry later
{:error, :unmet_dependencies}

# Other error
{:error, term()}
```

### Entry Types

Entries specify what to add to the graph:

```elixir
# Add a new vertex
{:vertex, %MyVertex{...}}

# Add an edge between vertices
{:edge, from_vertex, to_vertex, label}
```

**Important:** Use actual vertex structs in entries, not IDs.

## Provenance and Automatic Cleanup

Vertices created by an introspector are automatically tracked by
**provenance** - they are attached to the source vertex being
introspected. This provides automatic cleanup when things change:

### How Provenance Works

When you return vertices from `introspect_vertex/2`, Clarity
automatically tracks provenance - no explicit edge required:

```elixir
def introspect_vertex(%Vertex.Module{module: MyModule}, graph) do
  custom_vertex = %MyVertex{name: "example"}

  # Provenance is automatic! custom_vertex is tracked as
  # created from the MyModule vertex just by returning it here
  {:ok, [
    {:vertex, custom_vertex}
    # You can optionally add edges for visualization:
    # {:edge, module_vertex, custom_vertex, :defines}
  ]}
end
```

Clarity automatically tracks that `custom_vertex` was created by
introspecting the `MyModule` vertex. If the module is recompiled or
removed:

1. **Pruning**: The old `MyModule` vertex is removed from the graph
2. **Cascade**: All vertices attached by provenance are also deleted
3. **Reload**: The new `MyModule` vertex is introspected fresh
4. **Rebuild**: New vertices are created with updated information

### Benefits

- **No stale data** - Old vertices are automatically cleaned up
- **No manual tracking** - You don't need to manage deletion
- **Consistency** - Graph always reflects current state
- **Incremental updates** - Only changed modules are re-introspected

### Example: Module Recompilation

```elixir
# Initial compilation of MyModule
# Introspector creates: CustomEntity vertex
# Provenance: CustomEntity -> MyModule

# User edits MyModule and recompiles
# 1. Old MyModule vertex pruned
# 2. CustomEntity vertex automatically deleted (provenance)
# 3. New MyModule vertex created
# 4. Introspector runs again
# 5. New CustomEntity vertex created
```

This ensures the graph always reflects the current state of your
codebase without manual cleanup logic.

## Handling Dependencies

When your introspector needs data that might not be in the graph
yet, check for it and return `:unmet_dependencies` if missing:

```elixir
@impl Clarity.Introspector
def introspect_vertex(%Vertex.Module{module: module}, graph) do
  # Need the application vertex for this module
  app_id = Clarity.Vertex.Util.id(Vertex.Application,
                                    [module.app])

  case Graph.get_vertex(graph, app_id) do
    nil ->
      # Application vertex not yet in graph, retry later
      {:error, :unmet_dependencies}

    app_vertex ->
      # Process with app_vertex
      custom_vertex = %MyVertex{...}

      {:ok, [
        {:vertex, custom_vertex},
        {:edge, app_vertex, custom_vertex, :contains}
      ]}
  end
end
```

Clarity will automatically retry introspectors that return
`:unmet_dependencies` once more vertices are available.

## Edge Labels

Edge labels describe the relationship between vertices. Use clear,
descriptive labels:

```elixir
# Good labels - describe the relationship
{:edge, resource_vertex, action_vertex, :has_action}
{:edge, module_vertex, function_vertex, :defines}
{:edge, controller_vertex, view_vertex, :renders}

# Avoid vague labels
{:edge, vertex_a, vertex_b, :related}
{:edge, vertex_a, vertex_b, :connection}
```

## Complete Example

Here's a complete introspector that discovers custom entities:

```elixir
defmodule MyApp.CustomEntityIntrospector do
  @moduledoc """
  Discovers modules that implement the CustomEntity behaviour
  and adds them as vertices in the graph.
  """

  @behaviour Clarity.Introspector

  alias Clarity.Graph
  alias Clarity.Vertex
  alias MyApp.Vertex.CustomEntity

  @impl Clarity.Introspector
  def source_vertex_types, do: [Vertex.Module]

  @impl Clarity.Introspector
  def introspect_vertex(%Vertex.Module{module: module}, graph) do
    case Code.ensure_loaded(module) do
      {:module, ^module} ->
        if implements_custom_entity?(module) do
          create_custom_entity_vertex(module, graph)
        else
          {:ok, []}
        end

      _ ->
        {:ok, []}
    end
  end

  def introspect_vertex(_vertex, _graph), do: {:ok, []}

  defp implements_custom_entity?(module) do
    function_exported?(module, :custom_entity_config, 0)
  end

  defp create_custom_entity_vertex(module, graph) do
    config = module.custom_entity_config()

    custom_vertex = %CustomEntity{
      name: config.name,
      module: module,
      category: config.category
    }

    # Find the module vertex to create edge
    module_id = Clarity.Vertex.Util.id(Vertex.Module,
                                        [module, 0])
    module_vertex = Graph.get_vertex!(graph, module_id)

    {:ok, [
      {:vertex, custom_vertex},
      {:edge, module_vertex, custom_vertex, :implements}
    ]}
  end
end
```

## Pattern: Processing Nested Entities

A common pattern is discovering nested entities within a parent:

```elixir
defmodule MyApp.FieldIntrospector do
  @behaviour Clarity.Introspector

  alias Clarity.Graph
  alias Clarity.Vertex
  alias MyApp.Vertex.CustomEntity
  alias MyApp.Vertex.Field

  @impl Clarity.Introspector
  def source_vertex_types, do: [CustomEntity]

  @impl Clarity.Introspector
  def introspect_vertex(%CustomEntity{} = entity, graph) do
    # Extract nested fields from the entity
    fields = get_fields_from_entity(entity)

    entries =
      Enum.flat_map(fields, fn field ->
        field_vertex = %Field{
          name: field.name,
          parent: entity.name,
          type: field.type
        }

        [
          {:vertex, field_vertex},
          {:edge, entity, field_vertex, :has_field}
        ]
      end)

    {:ok, entries}
  end

  def introspect_vertex(_vertex, _graph), do: {:ok, []}

  defp get_fields_from_entity(entity) do
    # Extract fields from entity configuration
    entity.module.fields()
  end
end
```

**Key pattern:** When a parent vertex contains multiple nested
entities, create vertices for each nested entity and edges
connecting them to the parent.

## Pattern: Extracting Relationships

When entities reference each other, create edges to represent those
relationships:

```elixir
defp process_references(entity, graph) do
  # Entity references other entities by module
  referenced_modules = entity.references

  entity_entries = [{:vertex, entity_vertex}]

  edge_entries =
    Enum.flat_map(referenced_modules, fn ref_module ->
      ref_id = Clarity.Vertex.Util.id(SomeVertex, [ref_module])

      case Graph.get_vertex(graph, ref_id) do
        nil ->
          # Referenced vertex not in graph yet
          []

        ref_vertex ->
          [{:edge, entity_vertex, ref_vertex, :references}]
      end
    end)

  {:ok, entity_entries ++ edge_entries}
end
```

**Note:** It's okay if some edges can't be created because
referenced vertices don't exist. Only create edges for vertices that
are already in the graph.

## Pattern: Module Detection

Always use `Code.ensure_loaded/1` before checking module functions:

```elixir
@impl Clarity.Introspector
def introspect_vertex(%Vertex.Module{module: module}, graph) do
  case Code.ensure_loaded(module) do
    {:module, ^module} ->
      if function_exported?(module, :__info__, 1) do
        process_module(module, graph)
      else
        {:ok, []}
      end

    {:error, _reason} ->
      # Module can't be loaded, skip it
      {:ok, []}
  end
end
```

## Testing Introspectors

Test introspectors by creating test vertices and verifying the
output:

```elixir
defmodule MyApp.CustomEntityIntrospectorTest do
  use ExUnit.Case, async: true

  alias Clarity.Graph
  alias Clarity.Vertex
  alias MyApp.CustomEntityIntrospector

  test "creates vertex for custom entity module" do
    module = MyApp.TestCustomEntity
    module_vertex = %Vertex.Module{module: module, version: 0}

    graph =
      Graph.new()
      |> Graph.add_vertex(module_vertex)

    assert {:ok, entries} =
      CustomEntityIntrospector.introspect_vertex(
        module_vertex,
        graph
      )

    # Verify vertex was created
    assert [{:vertex, custom_vertex}, {:edge, _, _, _}] =
      entries
    assert custom_vertex.module == module
  end

  test "returns empty list for non-custom-entity modules" do
    module = String
    module_vertex = %Vertex.Module{module: module, version: 0}
    graph = Graph.new()

    assert {:ok, []} =
      CustomEntityIntrospector.introspect_vertex(
        module_vertex,
        graph
      )
  end
end
```

## Real-World Examples

See existing introspectors in the Clarity codebase:

- **Simple**: `lib/clarity/introspector/application.ex`
- **Module-based**: `lib/clarity/introspector/module.ex`
- **Ash Resource**: `lib/clarity/introspector/ash/resource.ex`
- **With Dependencies**: `lib/clarity/introspector/ash/domain.ex`
- **Spark DSL**: `lib/clarity/introspector/spark/dsl.ex`

## Common Pitfalls

### Using IDs Instead of Vertex Structs

**Problem:** Returning vertex IDs instead of vertex structs.

**Solution:** Always use actual vertex structs in entries:

```elixir
# Bad
{:ok, [{:vertex, "vertex-id"}]}

# Good
{:ok, [{:vertex, %MyVertex{...}}]}
```

### Not Handling Missing Dependencies

**Problem:** Assuming needed vertices are always in the graph.

**Solution:** Check for dependencies and return
`:unmet_dependencies` if missing:

```elixir
# Bad - crashes if dependency not found
dep_vertex = Graph.get_vertex!(graph, dep_id)

# Good - returns error for retry
case Graph.get_vertex(graph, dep_id) do
  nil -> {:error, :unmet_dependencies}
  dep_vertex -> process(dep_vertex)
end
```

### Forgetting Code.ensure_loaded

**Problem:** Calling module functions without ensuring module is
loaded.

**Solution:** Always call `Code.ensure_loaded/1` first:

```elixir
# Bad
if function_exported?(module, :func, 0) do

# Good
case Code.ensure_loaded(module) do
  {:module, ^module} ->
    if function_exported?(module, :func, 0) do
```

### Creating Duplicate Vertices

**Problem:** Creating vertices that already exist.

**Solution:** Check if vertex exists before creating, or let
Clarity handle deduplication (vertices with same ID are
automatically deduplicated).

## Performance Considerations

- Keep introspectors fast - they run for many vertices
- Avoid expensive computations in introspectors
- Don't perform I/O operations if possible
- Cache expensive lookups when processing multiple vertices

## Next Steps

After creating an introspector:

1. Ensure vertices created by your introspector have unique IDs
2. Create content providers to display information about your
   vertices (see `clarity:content-providers`)
3. Update or create lenses to include your vertices
   (see `clarity:lensmakers`)
