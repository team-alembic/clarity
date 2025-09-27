defmodule Clarity.Introspector.ApplicationTest do
  use ExUnit.Case, async: true

  alias Clarity.Introspector.Application, as: ApplicationIntrospector
  alias Clarity.Vertex

  describe inspect(&ApplicationIntrospector.introspect_vertex/2) do
    test "returns application vertices and edges for root vertex" do
      graph = Clarity.Graph.new()
      root_vertex = %Vertex.Root{}

      result = ApplicationIntrospector.introspect_vertex(root_vertex, graph)

      loaded_apps = Application.loaded_applications()

      # Should return vertices and edges for all loaded applications
      vertices = Enum.filter(result, &match?({:vertex, %Vertex.Application{}}, &1))
      edges = Enum.filter(result, &match?({:edge, _, _, :application}, &1))

      assert length(vertices) == length(loaded_apps)
      assert length(edges) == length(loaded_apps)

      for {:vertex, app_vertex} <- vertices do
        assert %Vertex.Application{} = app_vertex
        assert app_vertex.app in Enum.map(loaded_apps, fn {app, _, _} -> app end)
      end

      for {:edge, from_vertex, to_vertex, :application} <- edges do
        assert from_vertex == root_vertex
        assert %Vertex.Application{} = to_vertex
      end
    end

    test "returns empty list for non-root vertices" do
      graph = Clarity.Graph.new()
      app_vertex = %Vertex.Application{app: :test_app, description: "Test", version: "1.0.0"}

      result = ApplicationIntrospector.introspect_vertex(app_vertex, graph)

      assert result == []
    end
  end
end
