defmodule Clarity.Introspector.ApplicationTest do
  use ExUnit.Case, async: true

  alias Clarity.Introspector.Application, as: ApplicationIntrospector
  alias Clarity.Vertex

  describe inspect(&ApplicationIntrospector.introspect/1) do
    test "adds application vertices for all loaded applications when root vertex exists" do
      graph = :digraph.new()
      root_vertex = %Vertex.Root{}
      :digraph.add_vertex(graph, root_vertex, Vertex.unique_id(root_vertex))

      result_graph = ApplicationIntrospector.introspect(graph)

      assert result_graph == graph

      vertices = :digraph.vertices(graph)
      app_vertices = Enum.filter(vertices, &match?(%Vertex.Application{}, &1))

      loaded_apps = Application.loaded_applications()
      assert length(app_vertices) == length(loaded_apps)

      for app_vertex <- app_vertices do
        assert %Vertex.Application{} = app_vertex
        assert app_vertex.app in Enum.map(loaded_apps, fn {app, _, _} -> app end)
      end
    end

    test "creates edges from root to application vertices" do
      graph = :digraph.new()
      root_vertex = %Vertex.Root{}
      :digraph.add_vertex(graph, root_vertex, Vertex.unique_id(root_vertex))

      ApplicationIntrospector.introspect(graph)

      vertices = :digraph.vertices(graph)
      app_vertices = Enum.filter(vertices, &match?(%Vertex.Application{}, &1))

      for app_vertex <- app_vertices do
        edges = :digraph.in_edges(graph, app_vertex)
        assert length(edges) == 1

        [edge] = edges
        {^edge, ^root_vertex, ^app_vertex, :application} = :digraph.edge(graph, edge)
      end
    end

    test "does nothing when no root vertex exists" do
      graph = :digraph.new()

      result_graph = ApplicationIntrospector.introspect(graph)

      assert result_graph == graph
      assert :digraph.vertices(graph) == []
    end

    test "returns the same graph instance" do
      graph = :digraph.new()

      result = ApplicationIntrospector.introspect(graph)

      assert result == graph
    end
  end

  describe inspect(&ApplicationIntrospector.post_introspect/1) do
    test "removes application vertices with no outgoing edges and only one incoming edge" do
      graph = :digraph.new()
      root_vertex = %Vertex.Root{}
      :digraph.add_vertex(graph, root_vertex, Vertex.unique_id(root_vertex))

      app_vertex = %Vertex.Application{app: :test_app, description: "Test", version: "1.0.0"}
      :digraph.add_vertex(graph, app_vertex, Vertex.unique_id(app_vertex))
      :digraph.add_edge(graph, root_vertex, app_vertex, :application)

      ApplicationIntrospector.post_introspect(graph)

      vertices = :digraph.vertices(graph)
      assert root_vertex in vertices
      refute app_vertex in vertices
    end

    test "keeps application vertices with outgoing edges" do
      graph = :digraph.new()
      root_vertex = %Vertex.Root{}
      :digraph.add_vertex(graph, root_vertex, Vertex.unique_id(root_vertex))

      app_vertex = %Vertex.Application{app: :test_app, description: "Test", version: "1.0.0"}
      :digraph.add_vertex(graph, app_vertex, Vertex.unique_id(app_vertex))
      :digraph.add_edge(graph, root_vertex, app_vertex, :application)

      other_vertex = %Vertex.Root{}
      :digraph.add_vertex(graph, other_vertex, "other")
      :digraph.add_edge(graph, app_vertex, other_vertex, :test)

      ApplicationIntrospector.post_introspect(graph)

      vertices = :digraph.vertices(graph)
      assert app_vertex in vertices
    end

    test "keeps application vertices with multiple incoming edges" do
      graph = :digraph.new()
      root_vertex = %Vertex.Root{}
      :digraph.add_vertex(graph, root_vertex, Vertex.unique_id(root_vertex))

      other_vertex = %Vertex.Root{}
      :digraph.add_vertex(graph, other_vertex, "other")

      app_vertex = %Vertex.Application{app: :test_app, description: "Test", version: "1.0.0"}
      :digraph.add_vertex(graph, app_vertex, Vertex.unique_id(app_vertex))
      :digraph.add_edge(graph, root_vertex, app_vertex, :application)
      :digraph.add_edge(graph, other_vertex, app_vertex, :test)

      ApplicationIntrospector.post_introspect(graph)

      vertices = :digraph.vertices(graph)
      assert app_vertex in vertices
    end

    test "returns the same graph instance" do
      graph = :digraph.new()

      result = ApplicationIntrospector.post_introspect(graph)

      assert result == graph
    end
  end
end
