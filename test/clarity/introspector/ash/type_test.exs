defmodule Clarity.Introspector.Ash.TypeTest do
  use ExUnit.Case, async: true

  alias Clarity.Introspector.Ash.Type, as: TypeIntrospector
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Type
  alias Demo.Accounts.User

  describe inspect(&TypeIntrospector.introspect/1) do
    test "does nothing when no field vertices exist" do
      graph = :digraph.new()

      # Add an application vertex but no field vertices
      app_vertex = %Vertex.Application{app: :test_app, description: "Test", version: "1.0.0"}
      :digraph.add_vertex(graph, app_vertex, Vertex.unique_id(app_vertex))

      result = TypeIntrospector.introspect(graph)

      assert result == graph
      vertices = :digraph.vertices(graph)
      assert length(vertices) == 1
      assert app_vertex in vertices
    end

    test "creates type vertices from field types and connects them properly" do
      graph = :digraph.new()

      # Create application vertices that might own type modules
      ash_app_vertex = %Vertex.Application{app: :ash, description: "Ash Framework", version: "3.0.0"}
      :digraph.add_vertex(graph, ash_app_vertex, Vertex.unique_id(ash_app_vertex))

      elixir_app_vertex = %Vertex.Application{app: :elixir, description: "Elixir", version: "1.0.0"}
      :digraph.add_vertex(graph, elixir_app_vertex, Vertex.unique_id(elixir_app_vertex))

      # Create an attribute vertex with a string type
      string_attribute = %Ash.Resource.Attribute{name: :first_name, type: Ash.Type.String}

      attribute_vertex = %Vertex.Ash.Attribute{
        attribute: string_attribute,
        resource: User
      }

      :digraph.add_vertex(graph, attribute_vertex, Vertex.unique_id(attribute_vertex))

      result = TypeIntrospector.introspect(graph)

      assert result == graph

      vertices = :digraph.vertices(graph)
      type_vertices = Enum.filter(vertices, &match?(%Type{}, &1))

      # Should create at least one type vertex
      assert length(type_vertices) > 0

      # Find the string type vertex
      string_type_vertex = Enum.find(type_vertices, &(&1.type == Ash.Type.String))
      assert string_type_vertex

      # Verify type vertex is connected to an application vertex
      app_edges =
        graph
        |> :digraph.in_edges(string_type_vertex)
        |> Enum.map(&:digraph.edge(graph, &1))
        |> Enum.filter(fn {_, from, _, label} -> match?(%Vertex.Application{}, from) and label == :type end)

      assert length(app_edges) > 0

      # Verify attribute vertex is connected to type vertex
      type_edges =
        graph
        |> :digraph.out_edges(attribute_vertex)
        |> Enum.map(&:digraph.edge(graph, &1))
        |> Enum.filter(fn {_, _, to, label} -> match?(%Type{}, to) and label == :type end)

      assert length(type_edges) > 0
    end

    test "returns the same graph instance" do
      graph = :digraph.new()

      result = TypeIntrospector.introspect(graph)

      assert result == graph
    end
  end
end
