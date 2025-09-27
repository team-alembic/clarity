defmodule Clarity.Introspector.Ash.TypeTest do
  use ExUnit.Case, async: true

  alias Clarity.Introspector.Ash.Type, as: TypeIntrospector
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Type
  alias Clarity.Vertex.Root

  describe inspect(&TypeIntrospector.introspect_vertex/2) do
    test "returns empty list for non-field vertices" do
      graph = Clarity.Graph.new()
      root_vertex = %Root{}

      assert [] = TypeIntrospector.introspect_vertex(root_vertex, graph)
    end

    test "creates type vertices for attribute vertices" do
      graph = Clarity.Graph.new()

      ash_app_vertex = %Vertex.Application{app: :ash, description: "Ash", version: "1.0.0"}
      Clarity.Graph.add_vertex(graph, ash_app_vertex, %Root{})

      attribute_vertex = %Vertex.Ash.Attribute{
        attribute: %{name: :first_name, type: Ash.Type.String},
        resource: Demo.Accounts.User
      }

      assert [
               {:vertex, %Type{type: Ash.Type.String}},
               {:edge, ^ash_app_vertex, %Type{type: Ash.Type.String}, :type},
               {:edge, ^attribute_vertex, %Type{type: Ash.Type.String}, :type}
               | _
             ] = TypeIntrospector.introspect_vertex(attribute_vertex, graph)
    end
  end
end
