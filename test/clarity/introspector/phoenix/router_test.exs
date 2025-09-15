defmodule Clarity.Introspector.Phoenix.RouterTest do
  use ExUnit.Case, async: true

  alias Clarity.Introspector.Phoenix.Router, as: RouterIntrospector
  alias Clarity.Vertex
  alias Clarity.Vertex.Phoenix.Router

  describe inspect(&RouterIntrospector.introspect/1) do
    test "does nothing when no application vertices exist" do
      graph = :digraph.new()

      # Add a non-application vertex
      root_vertex = %Vertex.Root{}
      :digraph.add_vertex(graph, root_vertex, Vertex.unique_id(root_vertex))

      result = RouterIntrospector.introspect(graph)

      assert result == graph
      vertices = :digraph.vertices(graph)
      assert length(vertices) == 1
      assert root_vertex in vertices
    end

    test "creates router vertices for applications with Phoenix routers" do
      graph = :digraph.new()

      # Create an application vertex for clarity (which has DemoWeb.Router)
      clarity_app_vertex = %Vertex.Application{app: :clarity, description: "Clarity App", version: "1.0.0"}
      :digraph.add_vertex(graph, clarity_app_vertex, Vertex.unique_id(clarity_app_vertex))

      result = RouterIntrospector.introspect(graph)

      assert result == graph

      vertices = :digraph.vertices(graph)
      router_vertices = Enum.filter(vertices, &match?(%Router{}, &1))

      # Should create at least one router vertex (DemoWeb.Router)
      assert length(router_vertices) > 0

      # Find the DemoWeb.Router vertex
      demo_router = Enum.find(router_vertices, &(&1.router == DemoWeb.Router))
      assert demo_router

      # Verify router vertex is connected to the application vertex
      edges = :digraph.in_edges(graph, demo_router)
      assert length(edges) == 1

      [edge] = edges
      {^edge, ^clarity_app_vertex, ^demo_router, "router"} = :digraph.edge(graph, edge)
    end

    test "does nothing for applications without Phoenix routers" do
      graph = :digraph.new()

      # Create an application vertex for an app without routers
      test_app_vertex = %Vertex.Application{app: :test_app, description: "Test App", version: "1.0.0"}
      :digraph.add_vertex(graph, test_app_vertex, Vertex.unique_id(test_app_vertex))

      result = RouterIntrospector.introspect(graph)

      assert result == graph
      vertices = :digraph.vertices(graph)
      router_vertices = Enum.filter(vertices, &match?(%Router{}, &1))

      # Should not create any router vertices
      assert router_vertices == []
    end

    test "returns the same graph instance" do
      graph = :digraph.new()

      result = RouterIntrospector.introspect(graph)

      assert result == graph
    end
  end
end
