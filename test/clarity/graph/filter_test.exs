defmodule Clarity.Graph.FilterTest do
  use ExUnit.Case, async: true

  alias Clarity.Graph
  alias Clarity.Graph.Filter
  alias Clarity.Vertex.Application
  alias Clarity.Vertex.Module
  alias Clarity.Vertex.Root

  describe "within_steps/3" do
    setup do
      # Create a test graph: root -> app -> mod1 -> mod2
      graph = Graph.new()
      app = %Application{app: :test_app, description: "Test App", version: "1.0.0"}
      mod1 = %Module{module: TestMod1}
      mod2 = %Module{module: TestMod2}

      Graph.add_vertex(graph, app, %Root{})
      Graph.add_vertex(graph, mod1, app)
      Graph.add_vertex(graph, mod2, mod1)

      Graph.add_edge(graph, %Root{}, app, :application)
      Graph.add_edge(graph, app, mod1, :module)
      Graph.add_edge(graph, mod1, mod2, :dependency)

      %{graph: graph, app: app, mod1: mod1, mod2: mod2}
    end

    test "filters vertices within specified steps", %{graph: graph, app: app, mod1: mod1} do
      # Filter from root with 1 outgoing step
      filter_fn = Filter.within_steps(%Root{}, 1, 0)
      filtered_graph = Graph.filter(graph, filter_fn)
      vertices = Graph.vertices(filtered_graph)

      assert length(vertices) == 2
      assert %Root{} in vertices
      assert app in vertices
      refute mod1 in vertices
    end

    test "can be used with Graph.filter/2", %{graph: graph, app: app, mod1: mod1} do
      # Test the filter works correctly with Graph.filter/2
      filtered_graph = Graph.filter(graph, Filter.within_steps(%Root{}, 2, 0))
      vertices = Graph.vertices(filtered_graph)

      assert length(vertices) == 3
      assert %Root{} in vertices
      assert app in vertices
      assert mod1 in vertices
    end
  end

  describe "reachable_from/1" do
    setup do
      # Create branching graph: root -> app1 -> mod1
      #                              -> app2 -> mod2
      #                        isolated -> mod3
      graph = Graph.new()
      app1 = %Application{app: :app1, description: "App 1", version: "1.0.0"}
      app2 = %Application{app: :app2, description: "App 2", version: "1.0.0"}
      mod1 = %Module{module: Mod1}
      mod2 = %Module{module: Mod2}
      isolated = %Module{module: Isolated}
      mod3 = %Module{module: Mod3}

      Graph.add_vertex(graph, app1, %Root{})
      Graph.add_vertex(graph, app2, %Root{})
      Graph.add_vertex(graph, mod1, app1)
      Graph.add_vertex(graph, mod2, app2)
      Graph.add_vertex(graph, isolated, %Root{})
      Graph.add_vertex(graph, mod3, isolated)

      Graph.add_edge(graph, %Root{}, app1, :application)
      Graph.add_edge(graph, %Root{}, app2, :application)
      Graph.add_edge(graph, app1, mod1, :module)
      Graph.add_edge(graph, app2, mod2, :module)
      Graph.add_edge(graph, isolated, mod3, :module)

      %{graph: graph, app1: app1, app2: app2, mod1: mod1, mod2: mod2, isolated: isolated, mod3: mod3}
    end

    test "filters to vertices reachable from specified vertices", %{
      graph: graph,
      app1: app1,
      mod1: mod1,
      isolated: isolated,
      mod3: mod3
    } do
      # Filter to vertices reachable from root
      filter_fn = Filter.reachable_from([%Root{}])
      filtered_graph = Graph.filter(graph, filter_fn)
      vertices = Graph.vertices(filtered_graph)

      # Should include everything reachable from root
      assert %Root{} in vertices
      assert app1 in vertices
      assert mod1 in vertices
      # Should NOT include isolated branch
      refute isolated in vertices
      refute mod3 in vertices
    end

    test "works with multiple source vertices", %{
      graph: graph,
      app1: app1,
      mod1: mod1,
      isolated: isolated,
      mod3: mod3
    } do
      # Filter to vertices reachable from app1 OR isolated
      filter_fn = Filter.reachable_from([app1, isolated])
      filtered_graph = Graph.filter(graph, filter_fn)
      vertices = Graph.vertices(filtered_graph)

      # Should include both branches
      assert app1 in vertices
      assert mod1 in vertices
      assert isolated in vertices
      assert mod3 in vertices
      # Should NOT include root
      refute %Root{} in vertices
    end
  end

  describe "vertex_type/1" do
    setup do
      graph = Graph.new()
      app1 = %Application{app: :test_app, description: "Test App", version: "1.0.0"}
      app2 = %Application{app: :other_app, description: "Other App", version: "2.0.0"}
      mod1 = %Module{module: TestMod}
      mod2 = %Module{module: OtherMod}

      Graph.add_vertex(graph, app1, %Root{})
      Graph.add_vertex(graph, app2, %Root{})
      Graph.add_vertex(graph, mod1, %Root{})
      Graph.add_vertex(graph, mod2, %Root{})

      %{graph: graph, app1: app1, app2: app2, mod1: mod1, mod2: mod2}
    end

    test "filters to only specified vertex types", %{
      graph: graph,
      app1: app1,
      app2: app2,
      mod1: mod1,
      mod2: mod2
    } do
      # Filter to only application vertices
      filter_fn = Filter.vertex_type([Application])
      filtered_graph = Graph.filter(graph, filter_fn)
      vertices = Graph.vertices(filtered_graph)

      assert app1 in vertices
      assert app2 in vertices
      refute mod1 in vertices
      refute mod2 in vertices
      refute %Root{} in vertices
    end

    test "works with multiple types", %{graph: graph, app1: app1, mod1: mod1, mod2: mod2} do
      # Filter to modules and applications
      filter_fn = Filter.vertex_type([Module, Application])
      filtered_graph = Graph.filter(graph, filter_fn)
      vertices = Graph.vertices(filtered_graph)

      assert app1 in vertices
      assert mod1 in vertices
      assert mod2 in vertices
      refute %Root{} in vertices
    end

    test "works with single type in list", %{graph: graph, mod1: mod1, mod2: mod2, app1: app1} do
      # Filter to only modules
      filter_fn = Filter.vertex_type([Module])
      filtered_graph = Graph.filter(graph, filter_fn)
      vertices = Graph.vertices(filtered_graph)

      assert mod1 in vertices
      assert mod2 in vertices
      refute app1 in vertices
      refute %Root{} in vertices
    end

    test "returns empty when no vertices match type", %{graph: graph} do
      # Filter to non-existent type
      filter_fn = Filter.vertex_type([String])
      filtered_graph = Graph.filter(graph, filter_fn)
      vertices = Graph.vertices(filtered_graph)

      assert Enum.empty?(vertices)
    end
  end

  describe "custom/1" do
    setup do
      graph = Graph.new()
      app1 = %Application{app: :test_app, description: "Test App", version: "1.0.0"}
      mod1 = %Module{module: TestMod}
      mod2 = %Module{module: OtherMod}

      Graph.add_vertex(graph, app1, %Root{})
      Graph.add_vertex(graph, mod1, %Root{})
      Graph.add_vertex(graph, mod2, %Root{})

      %{graph: graph, app1: app1, mod1: mod1, mod2: mod2}
    end

    test "applies custom predicate function", %{graph: graph, mod1: mod1, mod2: mod2} do
      # Filter to only modules containing "Test"
      filter_fn =
        Filter.custom(fn vertex ->
          case vertex do
            %Module{module: module} -> String.contains?(to_string(module), "Test")
            _ -> false
          end
        end)

      filtered_graph = Graph.filter(graph, filter_fn)
      vertices = Graph.vertices(filtered_graph)

      # TestMod contains "Test"
      assert mod1 in vertices
      # OtherMod doesn't contain "Test"
      refute mod2 in vertices
      # Root is not a module
      refute %Root{} in vertices
    end
  end

  describe "logical operations" do
    setup do
      graph = Graph.new()
      app = %Application{app: :test_app, description: "Test App", version: "1.0.0"}
      mod1 = %Module{module: TestMod}
      mod2 = %Module{module: OtherMod}

      Graph.add_vertex(graph, app, %Root{})
      Graph.add_vertex(graph, mod1, app)
      Graph.add_vertex(graph, mod2, app)

      Graph.add_edge(graph, %Root{}, app, :application)
      Graph.add_edge(graph, app, mod1, :module)
      Graph.add_edge(graph, app, mod2, :module)

      %{graph: graph, app: app, mod1: mod1, mod2: mod2}
    end

    test "all/1 combines multiple filters with AND logic", %{graph: graph, app: app, mod1: mod1, mod2: mod2} do
      # Combine distance filter AND custom filter
      filter_fn =
        Filter.all([
          # Within 2 steps from root
          Filter.within_steps(%Root{}, 2, 0),
          # Only modules containing "Test"
          Filter.custom(fn vertex ->
            case vertex do
              %Module{module: module} -> String.contains?(to_string(module), "Test")
              _ -> false
            end
          end)
        ])

      filtered_graph = Graph.filter(graph, filter_fn)
      vertices = Graph.vertices(filtered_graph)

      # Should only include mod1 (TestMod) which passes both filters
      assert mod1 in vertices
      # Fails custom filter
      refute mod2 in vertices
      # Fails custom filter
      refute %Root{} in vertices
      # Fails custom filter
      refute app in vertices
    end

    test "list of filters uses ALL logic by default", %{graph: graph, app: app, mod1: mod1, mod2: mod2} do
      # List of filters should use ALL logic (backward compatibility)
      filters = [
        # Within 2 steps from root
        Filter.within_steps(%Root{}, 2, 0),
        # Only module vertices
        Filter.vertex_type([Module])
      ]

      filtered_graph = Graph.filter(graph, filters)
      vertices = Graph.vertices(filtered_graph)

      # Should include both modules that are within 2 steps
      assert mod1 in vertices
      assert mod2 in vertices
      # Should NOT include app (wrong type) or root (wrong type)
      refute app in vertices
      refute %Root{} in vertices
    end

    test "any/1 combines filters with OR logic", %{graph: graph, app: app, mod1: mod1, mod2: mod2} do
      # Modules OR applications (but not root)
      filter_fn =
        Filter.any([
          Filter.vertex_type([Module]),
          Filter.vertex_type([Application])
        ])

      filtered_graph = Graph.filter(graph, filter_fn)
      vertices = Graph.vertices(filtered_graph)

      # Should include modules and applications
      assert mod1 in vertices
      assert mod2 in vertices
      assert app in vertices
      # Should NOT include root (doesn't match either condition)
      refute %Root{} in vertices
    end

    test "negate/1 negates a filter", %{graph: graph, app: app, mod1: mod1, mod2: mod2} do
      # Everything except modules
      filter_fn = Filter.negate(Filter.vertex_type([Module]))

      filtered_graph = Graph.filter(graph, filter_fn)
      vertices = Graph.vertices(filtered_graph)

      # Should include root and application
      assert %Root{} in vertices
      assert app in vertices
      # Should NOT include modules
      refute mod1 in vertices
      refute mod2 in vertices
    end

    test "complex logical combinations", %{graph: graph, app: app, mod1: mod1, mod2: mod2} do
      # (Within 2 steps from root) AND (NOT modules)
      filter_fn =
        Filter.all([
          Filter.within_steps(%Root{}, 2, 0),
          Filter.negate(Filter.vertex_type([Module]))
        ])

      filtered_graph = Graph.filter(graph, filter_fn)
      vertices = Graph.vertices(filtered_graph)

      # Should include root and app (within range, not modules)
      assert %Root{} in vertices
      assert app in vertices
      # Should NOT include modules
      refute mod1 in vertices
      refute mod2 in vertices
    end

    test "works when composed filters have no overlap", %{graph: graph} do
      # Impossible combination: within 0 steps AND reachable from non-root
      app = %Application{app: :other_app, description: "Other App", version: "1.0.0"}
      Graph.add_vertex(graph, app, %Root{})

      filters = [
        # Only root
        Filter.within_steps(%Root{}, 0, 0),
        # Only reachable from app (not root)
        Filter.reachable_from([app])
      ]

      filtered_graph = Graph.filter(graph, filters)
      vertices = Graph.vertices(filtered_graph)

      # Should be empty - no vertex satisfies both conditions
      assert Enum.empty?(vertices)
    end
  end

  describe "integration with Graph.filter/2" do
    test "accepts single filter function" do
      graph = Graph.new()

      # Should work with single filter
      filtered_graph = Graph.filter(graph, Filter.custom(fn _ -> true end))
      vertices = Graph.vertices(filtered_graph)

      assert %Root{} in vertices
    end

    test "accepts list of filters" do
      graph = Graph.new()

      # Should work with list of filters
      filters = [
        Filter.custom(fn _ -> true end),
        Filter.custom(fn _ -> true end)
      ]

      filtered_graph = Graph.filter(graph, filters)
      vertices = Graph.vertices(filtered_graph)

      assert %Root{} in vertices
    end
  end
end
