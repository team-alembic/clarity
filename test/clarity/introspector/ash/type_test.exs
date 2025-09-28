defmodule Clarity.Introspector.Ash.TypeTest do
  use ExUnit.Case, async: true

  alias Clarity.Introspector.Ash.Type, as: TypeIntrospector
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Type
  alias Clarity.Vertex.Root

  describe inspect(&TypeIntrospector.introspect_vertex/2) do
    test "creates type edges for attribute vertices" do
      graph = Clarity.Graph.new()

      ash_app_vertex = %Vertex.Application{app: :ash, description: "Ash", version: "1.0.0"}
      Clarity.Graph.add_vertex(graph, ash_app_vertex, %Root{})

      attribute_vertex = %Vertex.Ash.Attribute{
        attribute: %{name: :first_name, type: Ash.Type.String},
        resource: Demo.Accounts.User
      }

      # Create a type vertex first so it exists in the graph
      type_vertex = %Type{type: Ash.Type.String}
      Clarity.Graph.add_vertex(graph, type_vertex, ash_app_vertex)

      assert {:ok,
              [
                {:edge, ^attribute_vertex, ^type_vertex, :type}
              ]} = TypeIntrospector.introspect_vertex(attribute_vertex, graph)
    end
  end
end
