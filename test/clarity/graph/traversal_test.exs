defmodule Clarity.Graph.TraversalTest do
  use ExUnit.Case, async: true

  alias Clarity.Graph
  alias Clarity.Graph.Traversal
  alias Clarity.Vertex.Application
  alias Clarity.Vertex.Module
  alias Clarity.Vertex.Root

  setup do
    graph = Graph.new()

    app = %Application{app: :traversal_test, description: "Test", version: "1.0.0"}
    mod1 = %Module{module: TraversalMod1}
    mod2 = %Module{module: TraversalMod2}
    mod3 = %Module{module: TraversalMod3}

    Graph.add_vertex(graph, app, %Root{})
    Graph.add_vertex(graph, mod1, app)
    Graph.add_vertex(graph, mod2, app)
    Graph.add_vertex(graph, mod3, mod2)
    Graph.add_edge(graph, %Root{}, app, :application)
    Graph.add_edge(graph, app, mod1, :module)
    Graph.add_edge(graph, app, mod2, :module)
    Graph.add_edge(graph, mod2, mod3, :dependency)

    on_exit(fn -> Graph.delete(graph) end)

    %{graph: graph, app: app, mod1: mod1, mod2: mod2, mod3: mod3}
  end

  describe "vertices_within_steps/4" do
    test "returns center vertex with 0 steps", %{graph: graph, app: app} do
      result = Traversal.vertices_within_steps(graph, app, 0, 0)

      assert MapSet.member?(result, Clarity.Vertex.id(app))
      assert MapSet.size(result) == 1
    end

    test "returns outgoing neighbors within steps", %{graph: graph, app: app, mod1: mod1, mod2: mod2} do
      result = Traversal.vertices_within_steps(graph, app, 1, 0)

      assert MapSet.member?(result, Clarity.Vertex.id(app))
      assert MapSet.member?(result, Clarity.Vertex.id(mod1))
      assert MapSet.member?(result, Clarity.Vertex.id(mod2))
    end

    test "returns incoming neighbors within steps", %{graph: graph, app: app} do
      result = Traversal.vertices_within_steps(graph, app, 0, 1)

      assert MapSet.member?(result, Clarity.Vertex.id(app))
      assert MapSet.member?(result, Clarity.Vertex.id(%Root{}))
    end

    test "traverses multiple steps outward", %{graph: graph, app: app, mod3: mod3} do
      result = Traversal.vertices_within_steps(graph, app, 2, 0)

      assert MapSet.member?(result, Clarity.Vertex.id(mod3))
    end
  end

  describe "reachable_from/2" do
    test "returns all vertices reachable from source", %{graph: graph, app: app, mod1: mod1, mod2: mod2, mod3: mod3} do
      result = Traversal.reachable_from(graph, [app])

      assert Clarity.Vertex.id(app) in result
      assert Clarity.Vertex.id(mod1) in result
      assert Clarity.Vertex.id(mod2) in result
      assert Clarity.Vertex.id(mod3) in result
    end

    test "includes source vertices themselves", %{graph: graph, mod1: mod1} do
      result = Traversal.reachable_from(graph, [mod1])

      assert Clarity.Vertex.id(mod1) in result
    end

    test "handles multiple source vertices", %{graph: graph, mod1: mod1, mod2: mod2, mod3: mod3} do
      result = Traversal.reachable_from(graph, [mod1, mod2])

      assert Clarity.Vertex.id(mod1) in result
      assert Clarity.Vertex.id(mod2) in result
      assert Clarity.Vertex.id(mod3) in result
    end
  end
end
