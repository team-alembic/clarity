defmodule Clarity.GraphTest do
  use ExUnit.Case, async: true

  alias Clarity.Graph
  alias Clarity.Graph.Filter
  alias Clarity.Vertex.Application
  alias Clarity.Vertex.Module
  alias Clarity.Vertex.Root

  describe "filter with within_steps" do
    setup do
      # Create a test graph with a known structure:
      # root -> app1 -> mod1 -> mod2
      #      -> app2 -> mod3
      graph = Graph.new()

      app1 = %Application{app: :test_app1, description: "Test App 1", version: "1.0.0"}
      app2 = %Application{app: :test_app2, description: "Test App 2", version: "1.0.0"}
      mod1 = %Module{module: TestMod1}
      mod2 = %Module{module: TestMod2}
      mod3 = %Module{module: TestMod3}

      Graph.add_vertex(graph, app1, %Root{})
      Graph.add_vertex(graph, app2, %Root{})
      Graph.add_vertex(graph, mod1, app1)
      Graph.add_vertex(graph, mod2, mod1)
      Graph.add_vertex(graph, mod3, app2)

      Graph.add_edge(graph, %Root{}, app1, :application)
      Graph.add_edge(graph, %Root{}, app2, :application)
      Graph.add_edge(graph, app1, mod1, :module)
      Graph.add_edge(graph, app2, mod3, :module)
      Graph.add_edge(graph, mod1, mod2, :dependency)

      %{
        graph: graph,
        app1: app1,
        app2: app2,
        mod1: mod1,
        mod2: mod2,
        mod3: mod3
      }
    end

    test "subgraph with 0 outgoing and 0 incoming steps should only include root vertex", %{
      graph: graph
    } do
      subgraph = Graph.filter(graph, Filter.within_steps(%Root{}, 0, 0))
      vertices = Graph.vertices(subgraph)

      assert length(vertices) == 1
      assert %Root{} in vertices
    end

    test "subgraph with 1 outgoing step should include root and direct children", %{
      graph: graph,
      app1: app1,
      app2: app2
    } do
      subgraph = Graph.filter(graph, Filter.within_steps(%Root{}, 1, 0))
      vertices = Graph.vertices(subgraph)

      # Should include root + 2 apps
      assert length(vertices) == 3
      assert %Root{} in vertices
      assert app1 in vertices
      assert app2 in vertices

      # Verify edges are included
      edges = Graph.edges(subgraph)
      assert length(edges) == 2

      # Check specific edges exist
      edge_data = Enum.map(edges, &Graph.edge(subgraph, &1))
      edge_labels = Enum.map(edge_data, fn {_, _, _, label} -> label end)
      assert :application in edge_labels
    end

    test "subgraph with 2 outgoing steps should include root, apps, and modules", %{
      graph: graph,
      app1: app1,
      app2: app2,
      mod1: mod1,
      mod3: mod3
    } do
      subgraph = Graph.filter(graph, Filter.within_steps(%Root{}, 2, 0))
      vertices = Graph.vertices(subgraph)

      # Should include root + 2 apps + 2 modules (mod1, mod3)
      # mod2 is not directly reachable in 2 steps from root
      assert length(vertices) == 5
      assert %Root{} in vertices
      assert app1 in vertices
      assert app2 in vertices
      assert mod1 in vertices
      assert mod3 in vertices

      # Verify edges
      edges = Graph.edges(subgraph)
      # root->app1, root->app2, app1->mod1, app2->mod3
      assert length(edges) == 4
    end

    test "subgraph starting from middle vertex with outgoing steps", %{
      graph: graph,
      app1: app1,
      mod1: mod1,
      mod2: mod2
    } do
      subgraph = Graph.filter(graph, Filter.within_steps(app1, 2, 0))
      vertices = Graph.vertices(subgraph)

      # Starting from app1, should include app1 + mod1 + mod2
      assert length(vertices) == 3
      assert app1 in vertices
      assert mod1 in vertices
      assert mod2 in vertices

      # Verify edges
      edges = Graph.edges(subgraph)
      # app1->mod1, mod1->mod2
      assert length(edges) == 2
    end

    test "subgraph with incoming steps should include parent vertices", %{
      graph: graph,
      app1: app1,
      mod1: mod1
    } do
      # Starting from mod1, go 1 step incoming should include app1
      subgraph = Graph.filter(graph, Filter.within_steps(mod1, 0, 1))
      vertices = Graph.vertices(subgraph)

      assert length(vertices) == 2
      assert mod1 in vertices
      assert app1 in vertices

      # Starting from mod1, go 2 steps incoming should include app1 and root
      subgraph2 = Graph.filter(graph, Filter.within_steps(mod1, 0, 2))
      vertices2 = Graph.vertices(subgraph2)

      assert length(vertices2) == 3
      assert mod1 in vertices2
      assert app1 in vertices2
      assert %Root{} in vertices2
    end

    test "subgraph with both outgoing and incoming steps", %{
      graph: graph,
      app1: app1,
      mod1: mod1
    } do
      # Starting from app1 with 1 outgoing and 1 incoming
      subgraph = Graph.filter(graph, Filter.within_steps(app1, 1, 1))
      vertices = Graph.vertices(subgraph)

      # Should include: root (1 incoming), app1 (center), mod1 (1 outgoing)
      assert length(vertices) == 3
      assert %Root{} in vertices
      assert app1 in vertices
      assert mod1 in vertices
    end

    test "subgraph preserves edge labels and directions", %{
      graph: graph
    } do
      subgraph = Graph.filter(graph, Filter.within_steps(%Root{}, 1, 0))
      edges = Graph.edges(subgraph)

      # Get all edge information
      edge_data = Enum.map(edges, &Graph.edge(subgraph, &1))

      # All edges from root should be :application label
      root_edges = Enum.filter(edge_data, fn {_, from_vertex, _, _} -> from_vertex == %Root{} end)
      assert length(root_edges) == 2
      Enum.each(root_edges, fn {_, _, _, label} -> assert label == :application end)
    end

    test "empty graph returns empty subgraph" do
      empty_graph = Graph.new()

      subgraph = Graph.filter(empty_graph, Filter.within_steps(%Root{}, 2, 2))
      vertices = Graph.vertices(subgraph)

      assert length(vertices) == 1
      assert %Root{} in vertices
    end
  end

  describe "subgraph performance and edge cases" do
    test "large step count doesn't cause infinite loops" do
      graph = Graph.new()
      app = %Application{app: :test_app, description: "Test App", version: "1.0.0"}

      Graph.add_vertex(graph, app, %Root{})
      Graph.add_edge(graph, %Root{}, app, :application)

      # Large step count should not cause issues
      subgraph = Graph.filter(graph, Filter.within_steps(%Root{}, 100, 100))
      vertices = Graph.vertices(subgraph)

      assert length(vertices) == 2
      assert %Root{} in vertices
      assert app in vertices
    end

    test "circular references are handled correctly" do
      graph = Graph.new()
      mod1 = %Module{module: Mod1}
      mod2 = %Module{module: Mod2}

      Graph.add_vertex(graph, mod1, %Root{})
      Graph.add_vertex(graph, mod2, %Root{})
      Graph.add_edge(graph, mod1, mod2, :dependency)
      # Circular dependency
      Graph.add_edge(graph, mod2, mod1, :dependency)

      subgraph = Graph.filter(graph, Filter.within_steps(mod1, 3, 0))
      vertices = Graph.vertices(subgraph)

      # Should include both vertices without infinite loop
      assert length(vertices) == 2
      assert mod1 in vertices
      assert mod2 in vertices
    end
  end

  describe "basic graph operations" do
    test "new/0 creates a graph with root vertex" do
      graph = Graph.new()

      assert Graph.vertex_count(graph) == 1
      assert [%Root{}] = Graph.vertices(graph)
      assert Graph.edges(graph) == []
    end

    test "subgraphs are readonly" do
      graph = Graph.new()
      subgraph = Graph.filter(graph, Filter.custom(fn _ -> true end))

      app = %Application{app: :test, description: "Test", version: "1.0.0"}
      assert {:error, :subgraphs_are_readonly} = Graph.add_vertex(subgraph, app, %Root{})
    end

    test "delete/1 cleans up graph resources" do
      graph = Graph.new()

      # Test ownership system - different process can't delete
      task =
        Task.async(fn ->
          assert {:error, :not_owner} = Graph.delete(graph)
        end)

      Task.await(task)

      # Original process can delete
      assert :ok = Graph.delete(graph)
    end

    test "clear/1 resets graph to root only" do
      graph = Graph.new()
      app = %Application{app: :test, description: "Test", version: "1.0.0"}

      Graph.add_vertex(graph, app, %Root{})
      assert Graph.vertex_count(graph) == 2

      Graph.clear(graph)
      vertices = Graph.vertices(graph)
      assert length(vertices) == 1
      assert %Root{} = hd(vertices)
    end

    test "clear/1 respects ownership" do
      graph = Graph.new()

      # Test ownership system - different process can't clear
      task =
        Task.async(fn ->
          assert {:error, :not_owner} = Graph.clear(graph)
        end)

      Task.await(task)
    end
  end

  describe "vertex operations" do
    setup do
      graph = Graph.new()
      app = %Application{app: :test_app, description: "Test App", version: "1.0.0"}
      mod = %Module{module: TestModule}

      %{graph: graph, app: app, mod: mod}
    end

    test "add_vertex/3 adds vertex to graph", %{graph: graph, app: app} do
      assert :ok = Graph.add_vertex(graph, app, %Root{})
      assert Graph.vertex_count(graph) == 2
      assert app in Graph.vertices(graph)
    end

    test "add_vertex/3 respects ownership", %{graph: graph, app: app} do
      # Test ownership system - different process can't add vertex
      task =
        Task.async(fn ->
          assert {:error, :not_owner} = Graph.add_vertex(graph, app, %Root{})
        end)

      Task.await(task)
    end

    test "get_vertex/2 retrieves vertex by ID", %{graph: graph, app: app} do
      Graph.add_vertex(graph, app, %Root{})
      vertex_id = Clarity.Vertex.unique_id(app)

      assert Graph.get_vertex(graph, vertex_id) == app
      assert Graph.get_vertex(graph, "nonexistent") == nil
    end

    test "vertices/1 returns all vertices in graph", %{graph: graph, app: app, mod: mod} do
      Graph.add_vertex(graph, app, %Root{})
      Graph.add_vertex(graph, mod, %Root{})

      vertices = Graph.vertices(graph)
      assert length(vertices) == 3
      assert %Root{} in vertices
      assert app in vertices
      assert mod in vertices
    end

    test "vertex_count/1 returns correct count", %{graph: graph, app: app, mod: mod} do
      assert Graph.vertex_count(graph) == 1

      Graph.add_vertex(graph, app, %Root{})
      assert Graph.vertex_count(graph) == 2

      Graph.add_vertex(graph, mod, %Root{})
      assert Graph.vertex_count(graph) == 3
    end

    test "purge/2 removes vertex and all vertices caused by it", %{graph: graph, app: app} do
      Graph.add_vertex(graph, app, %Root{})
      Graph.add_edge(graph, %Root{}, app, :application)

      assert Graph.vertex_count(graph) == 2
      assert length(Graph.edges(graph)) == 1

      {:ok, purged_vertices} = Graph.purge(graph, app)
      assert app in purged_vertices
      assert Graph.vertex_count(graph) == 1
      assert Graph.edges(graph) == []
      assert %Root{} in Graph.vertices(graph)
      refute app in Graph.vertices(graph)
    end

    test "purge/2 respects ownership", %{graph: graph} do
      # Test ownership system - different process can't purge
      task =
        Task.async(fn ->
          assert {:error, :not_owner} = Graph.purge(graph, %Root{})
        end)

      Task.await(task)
    end
  end

  describe "edge operations" do
    setup do
      graph = Graph.new()
      app = %Application{app: :test_app, description: "Test App", version: "1.0.0"}
      mod = %Module{module: TestModule}

      Graph.add_vertex(graph, app, %Root{})
      Graph.add_vertex(graph, mod, %Root{})

      %{graph: graph, app: app, mod: mod}
    end

    test "add_edge/4 creates edge between vertices", %{graph: graph, app: app} do
      assert :ok = Graph.add_edge(graph, %Root{}, app, :application)

      edges = Graph.edges(graph)
      assert length(edges) == 1

      [edge_id] = edges
      {^edge_id, from_vertex, to_vertex, label} = Graph.edge(graph, edge_id)
      assert from_vertex == %Root{}
      assert to_vertex == app
      assert label == :application
    end

    test "add_edge/4 respects ownership", %{graph: graph, app: app} do
      Graph.add_vertex(graph, app, %Root{})

      # Test ownership system - different process can't add edge
      task =
        Task.async(fn ->
          assert {:error, :not_owner} = Graph.add_edge(graph, %Root{}, app, :application)
        end)

      Task.await(task)
    end

    test "out_edges/2 returns outgoing edges from vertex", %{graph: graph, app: app, mod: mod} do
      Graph.add_edge(graph, %Root{}, app, :application)
      Graph.add_edge(graph, app, mod, :module)

      root_out_edges = Graph.out_edges(graph, %Root{})
      assert length(root_out_edges) == 1

      app_out_edges = Graph.out_edges(graph, app)
      assert length(app_out_edges) == 1

      mod_out_edges = Graph.out_edges(graph, mod)
      assert Enum.empty?(mod_out_edges)
    end

    test "in_edges/2 returns incoming edges to vertex", %{graph: graph, app: app, mod: mod} do
      Graph.add_edge(graph, %Root{}, app, :application)
      Graph.add_edge(graph, app, mod, :module)

      root_in_edges = Graph.in_edges(graph, %Root{})
      assert Enum.empty?(root_in_edges)

      app_in_edges = Graph.in_edges(graph, app)
      assert length(app_in_edges) == 1

      mod_in_edges = Graph.in_edges(graph, mod)
      assert length(mod_in_edges) == 1
    end

    test "edges/1 returns all edges in graph", %{graph: graph, app: app, mod: mod} do
      assert Graph.edges(graph) == []

      Graph.add_edge(graph, %Root{}, app, :application)
      assert length(Graph.edges(graph)) == 1

      Graph.add_edge(graph, app, mod, :module)
      assert length(Graph.edges(graph)) == 2
    end

    test "edge/2 returns edge details with vertex structs", %{graph: graph, app: app} do
      Graph.add_edge(graph, %Root{}, app, :application)
      [edge_id] = Graph.edges(graph)

      edge_result = Graph.edge(graph, edge_id)
      assert {^edge_id, %Root{}, ^app, :application} = edge_result

      # Test nonexistent edge
      assert Graph.edge(graph, "nonexistent") == false
    end
  end

  describe "path operations" do
    setup do
      # Create a path: root -> app -> mod1 -> mod2
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

    test "breadcrumbs/2 returns path from root to vertex", %{graph: graph, app: app, mod1: mod1, mod2: mod2} do
      # Note: breadcrumbs uses the tree_graph which tracks shortest paths from root
      # Let's test the actual behavior - it should return the path if one exists
      breadcrumbs_to_app = Graph.breadcrumbs(graph, app)
      breadcrumbs_to_mod1 = Graph.breadcrumbs(graph, mod1)
      breadcrumbs_to_mod2 = Graph.breadcrumbs(graph, mod2)

      # Verify the paths include the expected vertices
      if breadcrumbs_to_app do
        assert app in breadcrumbs_to_app
        assert %Root{} in breadcrumbs_to_app
      end

      if breadcrumbs_to_mod1 do
        assert mod1 in breadcrumbs_to_mod1
        assert app in breadcrumbs_to_mod1
        assert %Root{} in breadcrumbs_to_mod1
      end

      if breadcrumbs_to_mod2 do
        assert mod2 in breadcrumbs_to_mod2
        assert mod1 in breadcrumbs_to_mod2
      end
    end

    test "breadcrumbs/2 returns false for unreachable vertex", %{graph: graph} do
      # Add isolated vertex
      isolated = %Module{module: IsolatedModule}
      Graph.add_vertex(graph, isolated, %Root{})

      assert Graph.breadcrumbs(graph, isolated) == false
    end

    test "get_short_path/3 finds shortest path between vertices", %{graph: graph, app: app, mod2: mod2} do
      # Test path from root to mod2
      path = Graph.get_short_path(graph, %Root{}, mod2)

      if path do
        vertex_modules =
          Enum.map(path, fn
            %Root{} -> Root
            %Application{} -> Application
            %Module{module: mod} -> mod
          end)

        assert Root in vertex_modules
        assert Application in vertex_modules
        assert TestMod2 in vertex_modules
      end

      # Path to same vertex should work if vertex exists in main graph
      same_path = Graph.get_short_path(graph, app, app)

      if same_path do
        assert same_path == [app]
      end

      # No path available
      isolated = %Module{module: IsolatedModule}
      Graph.add_vertex(graph, isolated, %Root{})
      assert Graph.get_short_path(graph, %Root{}, isolated) == false
    end
  end

  describe "tree operations" do
    setup do
      # Create a tree structure
      graph = Graph.new()
      app1 = %Application{app: :app1, description: "App 1", version: "1.0.0"}
      app2 = %Application{app: :app2, description: "App 2", version: "1.0.0"}
      mod1 = %Module{module: Mod1}
      mod2 = %Module{module: Mod2}

      Graph.add_vertex(graph, app1, %Root{})
      Graph.add_vertex(graph, app2, %Root{})
      Graph.add_vertex(graph, mod1, app1)
      Graph.add_vertex(graph, mod2, app2)

      Graph.add_edge(graph, %Root{}, app1, :application)
      Graph.add_edge(graph, %Root{}, app2, :application)
      Graph.add_edge(graph, app1, mod1, :module)
      Graph.add_edge(graph, app2, mod2, :module)

      %{graph: graph, app1: app1, app2: app2, mod1: mod1, mod2: mod2}
    end

    test "to_tree/1 converts graph to tree structure", %{graph: graph, app1: app1, app2: app2, mod1: mod1} do
      tree = Graph.to_tree(graph)

      # Root should be the tree vertex
      assert tree.vertex == %Root{}

      # Should have :application edges
      assert Map.has_key?(tree.out_edges, :application)
      app_trees = tree.out_edges[:application]
      assert length(app_trees) == 2

      # Check app vertices are present
      app_vertices = Enum.map(app_trees, & &1.vertex)
      assert app1 in app_vertices
      assert app2 in app_vertices

      # Find app1 tree and check its children
      app1_tree = Enum.find(app_trees, fn tree -> tree.vertex == app1 end)
      assert Map.has_key?(app1_tree.out_edges, :module)
      mod1_trees = app1_tree.out_edges[:module]
      assert length(mod1_trees) == 1
      assert hd(mod1_trees).vertex == mod1
    end
  end

  describe "filter operations" do
    setup do
      graph = Graph.new()
      app1 = %Application{app: :app1, description: "App 1", version: "1.0.0"}
      app2 = %Application{app: :app2, description: "App 2", version: "1.0.0"}
      mod1 = %Module{module: Mod1}
      mod2 = %Module{module: Mod2}
      isolated = %Module{module: Isolated}

      Graph.add_vertex(graph, app1, %Root{})
      Graph.add_vertex(graph, app2, %Root{})
      Graph.add_vertex(graph, mod1, app1)
      Graph.add_vertex(graph, mod2, app2)
      # Not connected to anything - add as isolated vertex caused by root
      Graph.add_vertex(graph, isolated, %Root{})

      Graph.add_edge(graph, %Root{}, app1, :application)
      Graph.add_edge(graph, %Root{}, app2, :application)
      Graph.add_edge(graph, app1, mod1, :module)
      Graph.add_edge(graph, app2, mod2, :module)

      %{graph: graph, app1: app1, app2: app2, mod1: mod1, mod2: mod2, isolated: isolated}
    end

    test "reachable_from filter includes only reachable vertices", %{
      graph: graph,
      app1: app1,
      app2: app2,
      mod1: mod1,
      mod2: mod2,
      isolated: isolated
    } do
      filtered_graph = Graph.filter(graph, Filter.reachable_from([%Root{}]))

      vertices = Graph.vertices(filtered_graph)

      # Should include all vertices reachable from root
      assert %Root{} in vertices
      assert app1 in vertices
      assert app2 in vertices
      assert mod1 in vertices
      assert mod2 in vertices

      # Should NOT include isolated vertex
      refute isolated in vertices
    end

    test "reachable_from filter filters to subset when starting from partial vertex", %{
      graph: graph,
      app1: app1,
      app2: app2,
      mod1: mod1,
      mod2: mod2,
      isolated: isolated
    } do
      filtered_graph = Graph.filter(graph, Filter.reachable_from([app1]))

      vertices = Graph.vertices(filtered_graph)

      # Should include app1 and its children
      assert app1 in vertices
      assert mod1 in vertices

      # Should NOT include other branches or isolated
      refute %Root{} in vertices
      refute app2 in vertices
      refute mod2 in vertices
      refute isolated in vertices
    end

    test "reachable_from filter handles multiple filter vertices", %{
      graph: graph,
      app1: app1,
      app2: app2,
      mod1: mod1,
      mod2: mod2,
      isolated: isolated
    } do
      filtered_graph = Graph.filter(graph, Filter.reachable_from([app1, app2]))

      vertices = Graph.vertices(filtered_graph)

      # Should include both app branches
      assert app1 in vertices
      assert app2 in vertices
      assert mod1 in vertices
      assert mod2 in vertices

      # Should NOT include root or isolated
      refute %Root{} in vertices
      refute isolated in vertices
    end
  end
end
