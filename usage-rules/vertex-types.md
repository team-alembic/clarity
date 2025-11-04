# Creating Vertex Types

Vertex types represent nodes in the Clarity graph. Each vertex type
is a struct that implements the `Clarity.Vertex` protocol and
optionally other protocols for enhanced functionality.

## When to Create a Vertex Type

Create a new vertex type when you want to represent a distinct entity
in your codebase:

- Custom framework concepts (e.g., GraphQL schemas, custom DSLs)
- Business domain entities
- Configuration structures
- External integrations

## Step-by-Step Guide

### 1. Define the Struct

Create a module with a struct that holds the vertex data:

```elixir
defmodule MyApp.Vertex.CustomEntity do
  @moduledoc """
  Vertex implementation for custom entities in MyApp.
  """

  @type t() :: %__MODULE__{
    name: String.t(),
    metadata: map()
  }
  @enforce_keys [:name]
  defstruct [:name, :metadata]
end
```

**Key points:**
- Use `@enforce_keys` for required fields
- Define a `@type t()` spec for the struct
- Include a clear `@moduledoc`

### 2. Implement Required Protocol: `Clarity.Vertex`

The `Clarity.Vertex` protocol has three required callbacks:

```elixir
defimpl Clarity.Vertex, for: MyApp.Vertex.CustomEntity do
  alias Clarity.Vertex.Util

  @impl Clarity.Vertex
  def id(vertex) do
    Util.id(@for, vertex.name)
  end

  @impl Clarity.Vertex
  def type_label(_vertex) do
    "Custom Entity"
  end

  @impl Clarity.Vertex
  def name(vertex) do
    vertex.name
  end
end
```

**Protocol callbacks:**
- **`id/1`** - Returns unique identifier for this vertex
  - Use `Util.id(@for, components)` for consistency
  - `components` can be a string or list of strings
  - Must be globally unique across all vertices
- **`type_label/1`** - Returns human-readable type name
  - Used in UI for vertex type categorization
  - Should be a short, descriptive label
- **`name/1`** - Returns display name for this specific vertex
  - Used in UI as the vertex label
  - Should be meaningful to users

**Using `Clarity.Vertex.Util.id/2`:**

```elixir
# Single component
Util.id(@for, "my_entity")
# => "my-app-vertex-custom-entity:my-entity"

# Multiple components (creates hierarchy)
Util.id(@for, ["parent", "child", "field"])
# => "my-app-vertex-custom-entity:parent:child:field"

# With module as component
Util.id(@for, [MyApp.SomeModule])
# => "my-app-vertex-custom-entity:my-app-some-module"
```

### 3. Optional Protocols

Implement additional protocols for enhanced functionality:

#### GraphShapeProvider - Visual Shape

Controls the visual shape in graph visualizations:

```elixir
defimpl Clarity.Vertex.GraphShapeProvider,
       for: MyApp.Vertex.CustomEntity do

  @impl Clarity.Vertex.GraphShapeProvider
  def shape(_vertex) do
    "diamond"
  end
end
```

**Available shapes (Graphviz):**
- `"box"` (default)
- `"circle"`
- `"diamond"`
- `"ellipse"`
- `"component"`
- `"hexagon"`
- And more: https://graphviz.org/doc/info/shapes.html

#### GraphGroupProvider - Grouping

Provides hierarchical grouping in visualizations:

```elixir
defimpl Clarity.Vertex.GraphGroupProvider,
       for: MyApp.Vertex.CustomEntity do

  @impl Clarity.Vertex.GraphGroupProvider
  def graph_group(vertex) do
    ["My App", "Custom Entities", vertex.category]
  end
end
```

**Returns:** List of strings representing nesting hierarchy
(outer to inner).

#### ModuleProvider - Module Association

Associates vertex with an Elixir module:

```elixir
defimpl Clarity.Vertex.ModuleProvider,
       for: MyApp.Vertex.CustomEntity do

  @impl Clarity.Vertex.ModuleProvider
  def module(vertex) do
    vertex.module
  end
end
```

**Returns:** Module atom or `nil` if no association.

#### SourceLocationProvider - Source Location

Provides source code location for the vertex:

```elixir
defimpl Clarity.Vertex.SourceLocationProvider,
       for: MyApp.Vertex.CustomEntity do
  alias Clarity.SourceLocation

  @impl Clarity.Vertex.SourceLocationProvider
  def source_location(vertex) do
    SourceLocation.from_module(vertex.module)
  end
end
```

**Helpers available:**
- `SourceLocation.from_module/1` - Extract location from module
- `SourceLocation.new/3` - Create custom location

#### TooltipProvider - Hover Tooltips

Provides markdown content for hover tooltips:

```elixir
defimpl Clarity.Vertex.TooltipProvider,
       for: MyApp.Vertex.CustomEntity do

  @impl Clarity.Vertex.TooltipProvider
  def tooltip(vertex) do
    """
    # #{vertex.name}

    **Type**: Custom Entity
    **Category**: #{vertex.category}
    """
  end
end
```

**Returns:** Markdown string or `nil` for no tooltip.

## Complete Example

Here's a complete vertex type implementation:

```elixir
defmodule MyApp.Vertex.CustomEntity do
  @moduledoc """
  Represents a custom entity in MyApp.
  """

  @type t() :: %__MODULE__{
    name: String.t(),
    module: module(),
    category: String.t()
  }
  @enforce_keys [:name, :module]
  defstruct [:name, :module, :category]
end

defimpl Clarity.Vertex, for: MyApp.Vertex.CustomEntity do
  alias Clarity.Vertex.Util

  @impl Clarity.Vertex
  def id(vertex), do: Util.id(@for, vertex.name)

  @impl Clarity.Vertex
  def type_label(_vertex), do: "Custom Entity"

  @impl Clarity.Vertex
  def name(vertex), do: vertex.name
end

defimpl Clarity.Vertex.GraphShapeProvider,
       for: MyApp.Vertex.CustomEntity do
  @impl Clarity.Vertex.GraphShapeProvider
  def shape(_vertex), do: "diamond"
end

defimpl Clarity.Vertex.GraphGroupProvider,
       for: MyApp.Vertex.CustomEntity do
  @impl Clarity.Vertex.GraphGroupProvider
  def graph_group(vertex) do
    ["My App", "Custom", vertex.category || "Uncategorized"]
  end
end

defimpl Clarity.Vertex.ModuleProvider,
       for: MyApp.Vertex.CustomEntity do
  @impl Clarity.Vertex.ModuleProvider
  def module(vertex), do: vertex.module
end

defimpl Clarity.Vertex.SourceLocationProvider,
       for: MyApp.Vertex.CustomEntity do
  alias Clarity.SourceLocation

  @impl Clarity.Vertex.SourceLocationProvider
  def source_location(vertex) do
    SourceLocation.from_module(vertex.module)
  end
end

defimpl Clarity.Vertex.TooltipProvider,
       for: MyApp.Vertex.CustomEntity do
  @impl Clarity.Vertex.TooltipProvider
  def tooltip(vertex) do
    """
    # #{vertex.name}

    **Type**: Custom Entity
    **Module**: `#{inspect(vertex.module)}`
    """
  end
end
```

## Testing Vertex Types

Create thorough tests for all protocol implementations:

```elixir
defmodule MyApp.Vertex.CustomEntityTest do
  use ExUnit.Case, async: true

  alias Clarity.Vertex
  alias MyApp.Vertex.CustomEntity

  setup do
    vertex = %CustomEntity{
      name: "test_entity",
      module: MyApp.TestModule,
      category: "test"
    }
    {:ok, vertex: vertex}
  end

  describe inspect(&Vertex.id/1) do
    test "returns unique identifier", %{vertex: vertex} do
      expected = "my-app-vertex-custom-entity:test-entity"
      assert Vertex.id(vertex) == expected
    end
  end

  describe inspect(&Vertex.type_label/1) do
    test "returns correct type label", %{vertex: vertex} do
      assert Vertex.type_label(vertex) == "Custom Entity"
    end
  end

  describe inspect(&Vertex.name/1) do
    test "returns entity name", %{vertex: vertex} do
      assert Vertex.name(vertex) == "test_entity"
    end
  end
end
```

## Real-World Examples

See existing vertex types in the Clarity codebase:

- **Simple**: `lib/clarity/vertex/root.ex`
- **Module-based**: `lib/clarity/vertex/module.ex`
- **Complex**: `lib/clarity/vertex/ash/resource.ex`
- **With Grouping**: `lib/clarity/vertex/ash/action.ex`

## Common Pitfalls

### Non-Unique IDs

**Problem:** Multiple vertices with the same ID cause graph issues.
For example, multiple Ash resources can have an `:update` action.

**Solution:** Include enough identifying context in your vertex
struct and ID generation. Don't add random data - use the actual
context that makes the vertex unique:

```elixir
# Bad - multiple resources have :update action
%ActionVertex{name: :update}
Util.id(@for, [:update])
# Conflict! Multiple :update actions will have same ID

# Good - include parent resource
%ActionVertex{name: :update, resource: MyApp.User}
Util.id(@for, [MyApp.User, :update])
# Each resource's :update action has unique ID

# Bad - entity name alone might not be unique
%EntityVertex{name: "email"}
Util.id(@for, ["email"])

# Good - include parent/namespace
%EntityVertex{name: "email", parent: MyApp.User}
Util.id(@for, [MyApp.User, "email"])
```

### Missing @impl Annotation

**Problem:** Protocol implementations without `@impl`.

**Solution:** Always use `@impl ProtocolName`:

```elixir
# Correct
@impl Clarity.Vertex
def id(vertex), do: ...
```

### Inconsistent Naming

**Problem:** Using different names in `id/1` vs `name/1`.

**Solution:** Be consistent. `id/1` should be stable and unique,
`name/1` should be human-readable but can be the same value.

## Next Steps

After creating a vertex type:

1. Create an introspector to discover and add vertices of this type
   (see `clarity:introspectors`)
2. Create content providers to display information about these
   vertices (see `clarity:content-providers`)
3. Consider creating or updating lenses to include your vertex type
   (see `clarity:lensmakers`)
