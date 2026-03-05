# Clarity Usage Rules

Clarity is a code visualization and documentation tool for Elixir
projects. It introspects your codebase and builds a graph
representation that can be viewed through different "lenses"
(filtered perspectives).

## Architecture Overview

Clarity is built around four main extension points:

1. **Vertex Types** - Define new node types in the graph (modules,
   resources, custom entities)
2. **Introspectors** - Analyze code to discover and add
   vertices/edges to the graph
3. **Content Providers** - Display information about vertices in
   the UI
4. **Lensmakers** - Create filtered views of the graph for
   different audiences

All extensions are registered via application configuration,
allowing third-party libraries to seamlessly extend Clarity's
capabilities.

## Creating Extensions

For detailed guides on creating each type of extension, see the
sub-rules:

- **Creating Vertex Types**: See `clarity:vertex-types` usage
  rules
- **Creating Introspectors**: See `clarity:introspectors` usage
  rules
- **Creating Content Providers**: See `clarity:content-providers`
  usage rules
- **Creating Lenses**: See `clarity:lensmakers` usage rules

## Configuration

### Registering Extensions

Extensions are registered per-application in your config files:

```elixir
# In config/config.exs or config/runtime.exs
config :my_app, :clarity_introspectors, [
  MyApp.CustomIntrospector
]

config :my_app, :clarity_content_providers, [
  MyApp.CustomContent
]

config :my_app, :clarity_perspective_lensmakers, [
  MyApp.CustomLensmaker
]
```

Clarity automatically discovers and loads extensions from all
loaded applications.

### Global Configuration

```elixir
# Filter which applications to introspect
config :clarity, :introspector_applications,
  [:my_app, :phoenix, :ash]

# Set default lens
config :clarity, :default_perspective_lens, "debug"

# Configure editor integration
config :clarity, :editor,
  "code --goto __FILE__:__LINE__:__COLUMN__"

# Auto-start on application boot
config :clarity, :auto_start?, true

# Custom cache path
config :clarity, :cache_path, "/custom/path"

# Graph backend (default is Digraph)
config :clarity, :graph_backend, Clarity.Graph.Backend.Neo4j
config :clarity, Clarity.Graph.Backend.Neo4j,
  url: "http://localhost:7474",
  auth: {:basic, "neo4j", "password"},
  database: "clarity"
```

## Graph Query System

Clarity uses a tuple-based query syntax for filtering vertices:

### Comparison Operators

```elixir
# Equality
{:==, :vertex_type, Clarity.Vertex.Module}

# Inequality
{:!=, :vertex_id, "some-id"}

# Membership
{:in, :vertex_type,
 [Clarity.Vertex.Module, Clarity.Vertex.Application]}
```

### Logical Operators

```elixir
# AND - both conditions must be true
{:and, query1, query2}

# OR - either condition must be true
{:or, query1, query2}

# NOT - inverts the condition
{:not, query}
```

### Vertex Properties

```elixir
:vertex_id      # Result of Clarity.Vertex.id(vertex)
:vertex_type    # vertex.__struct__
```

### Filter Helpers

The `Clarity.Graph.Filter` module provides helpers for common
filter patterns:

```elixir
alias Clarity.Graph.Filter

# Filter by vertex type
Filter.vertex_type([Clarity.Vertex.Application])

# Filter by distance from a vertex
Filter.within_steps(center_vertex, max_outgoing_steps,
  max_incoming_steps)

# Filter by reachability
Filter.reachable_from([source_vertex1, source_vertex2])
```

## Common Patterns

### Vertex Identification

Use `Clarity.Vertex.Util.id/2` to create consistent vertex IDs:

```elixir
alias Clarity.Vertex.Util

# Single identifier component
Util.id(MyVertex, "component")
# => "Elixir.MyVertex:component"

# Multiple identifier components
Util.id(MyVertex, ["parent", "child", "field"])
# => "Elixir.MyVertex:parent:child:field"
```

### Module Detection

Use `Code.ensure_loaded/1` before `function_exported?/3`:

```elixir
def introspect_vertex(%Vertex.Module{module: module}, graph) do
  case Code.ensure_loaded(module) do
    {:module, ^module} ->
      if function_exported?(module, :__info__, 1) do
        # Process the module
      end
    _ ->
      {:ok, []}
  end
end
```

### Dependency Handling in Introspectors

When an introspector needs data that isn't in the graph yet:

```elixir
def introspect_vertex(vertex, graph) do
  case Clarity.Graph.get_vertex(graph, needed_vertex_id) do
    nil ->
      # Dependency not met, will retry later
      {:error, :unmet_dependencies}
    dependency_vertex ->
      # Process with dependency
      {:ok, entries}
  end
end
```

## Testing

### Testing Vertex Types

```elixir
defmodule MyApp.MyVertexTest do
  use ExUnit.Case, async: true

  alias Clarity.Vertex
  alias MyApp.MyVertex

  setup do
    vertex = %MyVertex{field: "value"}
    {:ok, vertex: vertex}
  end

  describe inspect(&Vertex.id/1) do
    test "returns unique identifier", %{vertex: vertex} do
      assert Vertex.id(vertex) == "expected-id"
    end
  end

  describe inspect(&Vertex.type_label/1) do
    test "returns correct type label", %{vertex: vertex} do
      assert Vertex.type_label(vertex) == "My Type"
    end
  end
end
```

### Ensuring Unique Vertex IDs

Vertex IDs must be globally unique across the entire graph. Include
enough identifying context in your vertex struct and ID generation:

```elixir
# Bad - multiple resources can have :update action
%Ash.Action{name: :update}
Util.id(@for, [:update])
# Multiple actions will have same ID - conflict!

# Good - include parent context
%Ash.Action{name: :update, resource: MyApp.User}
Util.id(@for, [MyApp.User, :update])
# Each resource's :update action has unique ID

# Bad - ambiguous field name
%CustomField{name: "email"}
Util.id(@for, ["email"])

# Good - include parent entity
%CustomField{name: "email", parent: MyApp.User}
Util.id(@for, [MyApp.User, "email"])
```

## Project Structure

```
lib/clarity/
├── vertex/                    # Vertex type definitions
├── introspector/              # Introspector implementations
├── content/                   # Content providers
├── perspective/
│   └── lensmaker/            # Lensmaker implementations
├── graph/
│   ├── backend.ex            # Backend behaviour
│   ├── backend/
│   │   ├── digraph.ex        # Default :digraph/ETS backend
│   │   ├── digraph/          # Digraph internal helpers
│   │   ├── cypher.ex         # Shared Cypher query builder
│   │   ├── neo4j.ex          # Neo4j HTTP backend
│   │   └── arcade_db.ex      # ArcadeDB HTTP backend
│   ├── filter.ex             # Filter helpers
│   ├── cache.ex              # Graph cache (persistence)
│   └── dot.ex                # DOT format export
├── graph.ex                  # Graph facade (delegates to backend)
├── vertex.ex                 # Vertex protocol
├── introspector.ex           # Introspector behavior
├── content.ex                # Content behavior
└── config.ex                 # Configuration management
```

## Development Tips

- Always implement required protocols/behaviors completely
- Provide clear error messages with context
- Test protocol implementations thoroughly
- Use descriptive names for vertices and relationships
- Document your extensions well
- Follow Elixir and Clarity conventions
- Use `@impl ModuleName` (not `@impl true`)
- Include `@spec` for all public functions except callbacks
