defmodule Clarity.Introspector.Ash.DataLayerTest do
  use ExUnit.Case, async: true

  alias Clarity.Introspector.Ash.DataLayer, as: DataLayerIntrospector
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.DataLayer

  describe inspect(&DataLayerIntrospector.introspect/1) do
    test "does nothing when no resource vertices exist" do
      graph = :digraph.new()

      # Add an application vertex but no resource vertices
      app_vertex = %Vertex.Application{app: :test_app, description: "Test", version: "1.0.0"}
      :digraph.add_vertex(graph, app_vertex, Vertex.unique_id(app_vertex))

      result = DataLayerIntrospector.introspect(graph)

      assert result == graph
      vertices = :digraph.vertices(graph)
      assert length(vertices) == 1
      assert app_vertex in vertices
    end

    test "creates data layer vertices and connects them to application and resource vertices" do
      graph = :digraph.new()

      # Create application vertices - both demo and ash apps
      demo_app_vertex = %Vertex.Application{app: :demo, description: "Demo App", version: "1.0.0"}
      :digraph.add_vertex(graph, demo_app_vertex, Vertex.unique_id(demo_app_vertex))

      ash_app_vertex = %Vertex.Application{app: :ash, description: "Ash Framework", version: "3.0.0"}
      :digraph.add_vertex(graph, ash_app_vertex, Vertex.unique_id(ash_app_vertex))

      # Create a resource vertex using the demo user resource
      resource_vertex = %Vertex.Ash.Resource{resource: Demo.Accounts.User}
      :digraph.add_vertex(graph, resource_vertex, Vertex.unique_id(resource_vertex))

      result = DataLayerIntrospector.introspect(graph)

      assert result == graph

      vertices = :digraph.vertices(graph)
      data_layer_vertices = Enum.filter(vertices, &match?(%DataLayer{}, &1))

      # Should create at least one data layer vertex
      assert length(data_layer_vertices) > 0

      # Check that data layer vertices are connected to application vertices
      for data_layer_vertex <- data_layer_vertices do
        app_edges =
          graph
          |> :digraph.in_edges(data_layer_vertex)
          |> Enum.map(&:digraph.edge(graph, &1))
          |> Enum.filter(fn {_, from, _, label} -> match?(%Vertex.Application{}, from) and label == :data_layer end)

        assert length(app_edges) > 0
      end

      # Check that resource vertices are connected to data layer vertices
      resource_out_edges =
        graph
        |> :digraph.out_edges(resource_vertex)
        |> Enum.map(&:digraph.edge(graph, &1))
        |> Enum.filter(fn {_, _, to, label} -> match?(%DataLayer{}, to) and label == :data_layer end)

      assert length(resource_out_edges) > 0
    end

    test "returns the same graph instance" do
      graph = :digraph.new()

      result = DataLayerIntrospector.introspect(graph)

      assert result == graph
    end
  end
end
