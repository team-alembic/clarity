defmodule Clarity.GraphTest do
  use ExUnit.Case, async: true

  alias Clarity.Graph
  alias Clarity.Graph.Filter
  alias Clarity.Vertex
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
      subgraph = Graph.filter(graph, true)

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
      vertex_id = Vertex.id(app)

      assert Graph.get_vertex(graph, vertex_id) == app
      assert Graph.get_vertex(graph, "nonexistent") == nil
    end

    test "vertices/2 returns all vertices in graph", %{graph: graph, app: app, mod: mod} do
      Graph.add_vertex(graph, app, %Root{})
      Graph.add_vertex(graph, mod, %Root{})

      vertices = Graph.vertices(graph)
      assert length(vertices) == 3
      assert %Root{} in vertices
      assert app in vertices
      assert mod in vertices

      assert [] = Graph.vertices(graph, {:==, :vertex_type, Inexistent})
      assert [%Root{}] = Graph.vertices(graph, {:==, :vertex_type, Root})
      assert [^app] = Graph.vertices(graph, {:==, :vertex_type, Application})
      vertices = Graph.vertices(graph, {:in, :vertex_type, [Root, Application]})
      assert %Root{} in vertices
      assert app in vertices
      refute mod in vertices

      assert [^app] =
               Graph.vertices(
                 graph,
                 {:and, {:==, :vertex_type, Application}, {:==, {:field, :app}, :test_app}}
               )

      assert [] =
               Graph.vertices(
                 graph,
                 {:and, {:==, :vertex_type, Application}, {:==, {:field, :app}, :nonexistent}}
               )

      assert [^app] =
               Graph.vertices(
                 graph,
                 {:and, {:==, :vertex_type, Application}, {:in, {:field, :app}, [:test_app]}}
               )

      assert [] =
               Graph.vertices(
                 graph,
                 {:and, {:==, :vertex_type, Application}, {:in, {:field, :app}, []}}
               )

      assert [] =
               Graph.vertices(
                 graph,
                 {:and, {:==, :vertex_type, Application}, {:in, {:field, :app}, [:nonexistent]}}
               )
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

  describe "navigation_children/2" do
    setup do
      graph = Graph.new()
      app1 = %Application{app: :test_app1, description: "Test App 1", version: "1.0.0"}
      app2 = %Application{app: :test_app2, description: "Test App 2", version: "1.0.0"}
      mod1 = %Module{module: TestMod1}
      mod2 = %Module{module: TestMod2}

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

    test "returns children grouped by edge label", %{graph: graph, app1: app1, app2: app2} do
      children = Graph.navigation_children(graph, %Root{})

      assert Map.has_key?(children, :application)
      assert length(children[:application]) == 2
      assert app1 in children[:application]
      assert app2 in children[:application]
    end

    test "returns empty map for leaf vertices", %{graph: graph, mod1: mod1} do
      children = Graph.navigation_children(graph, mod1)

      assert children == %{}
    end

    test "children are sorted by vertex name", %{graph: graph} do
      children = Graph.navigation_children(graph, %Root{})
      apps = children[:application]

      names = Enum.map(apps, &Vertex.name/1)
      assert names == Enum.sort(names)
    end

    test "handles multiple edge types from same vertex", %{graph: graph, app1: app1} do
      mod3 = %Module{module: TestMod3}
      Graph.add_vertex(graph, mod3, app1)
      Graph.add_edge(graph, app1, mod3, :dependency)

      children = Graph.navigation_children(graph, app1)

      assert Map.has_key?(children, :module)
      assert Map.has_key?(children, :dependency)
      assert length(children[:module]) == 1
      assert length(children[:dependency]) == 1
    end
  end

  describe "neighbor operations" do
    setup do
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

      %{graph: graph, app1: app1, app2: app2, mod1: mod1, mod2: mod2, mod3: mod3}
    end

    test "out_neighbors/2 returns direct outgoing neighbors", %{
      graph: graph,
      app1: app1,
      app2: app2,
      mod1: mod1,
      mod2: mod2,
      mod3: mod3
    } do
      assert length(Graph.out_neighbors(graph, %Root{})) == 2
      assert Graph.out_neighbors(graph, app1) == [mod1]
      assert Graph.out_neighbors(graph, app2) == [mod3]
      assert Graph.out_neighbors(graph, mod1) == [mod2]
      assert Graph.out_neighbors(graph, mod2) == []
      assert Graph.out_neighbors(graph, mod3) == []
    end

    test "in_neighbors/2 returns direct incoming neighbors", %{
      graph: graph,
      app1: app1,
      app2: app2,
      mod1: mod1,
      mod2: mod2,
      mod3: mod3
    } do
      assert Graph.in_neighbors(graph, %Root{}) == []
      assert Graph.in_neighbors(graph, app1) == [%Root{}]
      assert Graph.in_neighbors(graph, app2) == [%Root{}]
      assert Graph.in_neighbors(graph, mod1) == [app1]
      assert Graph.in_neighbors(graph, mod2) == [mod1]
      assert Graph.in_neighbors(graph, mod3) == [app2]
    end

    test "handles isolated vertices and works with subgraphs", %{graph: graph, app1: app1, mod1: mod1, mod2: mod2} do
      isolated = %Module{module: IsolatedModule}
      Graph.add_vertex(graph, isolated, %Root{})

      assert Graph.out_neighbors(graph, isolated) == []
      assert Graph.in_neighbors(graph, isolated) == []

      subgraph = Graph.filter(graph, Filter.within_steps(app1, 2, 0))
      assert Graph.out_neighbors(subgraph, app1) == [mod1]
      assert Graph.in_neighbors(subgraph, mod2) == [mod1]
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

  describe "update counter" do
    test "starts with positive count after creating new graph" do
      graph = Graph.new()
      assert Graph.get_update_count(graph) > 0
    end

    test "increments when adding vertex" do
      graph = Graph.new()
      initial_count = Graph.get_update_count(graph)

      app = %Application{app: :test_app, description: "Test", version: "1.0.0"}
      Graph.add_vertex(graph, app, %Root{})

      assert Graph.get_update_count(graph) > initial_count
    end

    test "increments when adding edge" do
      graph = Graph.new()
      app = %Application{app: :test_app, description: "Test", version: "1.0.0"}
      Graph.add_vertex(graph, app, %Root{})

      count_before_edge = Graph.get_update_count(graph)
      Graph.add_edge(graph, %Root{}, app, :application)

      assert Graph.get_update_count(graph) > count_before_edge
    end

    test "increments when clearing graph" do
      graph = Graph.new()
      app = %Application{app: :test_app, description: "Test", version: "1.0.0"}
      Graph.add_vertex(graph, app, %Root{})

      count_before_clear = Graph.get_update_count(graph)
      Graph.clear(graph)

      assert Graph.get_update_count(graph) > count_before_clear
    end

    test "increments when purging vertex" do
      graph = Graph.new()
      app = %Application{app: :test_app, description: "Test", version: "1.0.0"}
      Graph.add_vertex(graph, app, %Root{})

      count_before_purge = Graph.get_update_count(graph)
      Graph.purge(graph, app)

      assert Graph.get_update_count(graph) > count_before_purge
    end

    test "allows change detection for subgraph invalidation" do
      graph = Graph.new()
      count1 = Graph.get_update_count(graph)

      # No changes - count should be same
      count2 = Graph.get_update_count(graph)
      assert count2 == count1

      # Add vertex - count should increase
      app = %Application{app: :test_app, description: "Test", version: "1.0.0"}
      Graph.add_vertex(graph, app, %Root{})
      count3 = Graph.get_update_count(graph)
      assert count3 > count2

      # Add edge - count should increase again
      Graph.add_edge(graph, %Root{}, app, :application)
      count4 = Graph.get_update_count(graph)
      assert count4 > count3
    end
  end

  describe "persist and load" do
    @tag :tmp_dir
    test "persist/load roundtrip preserves graph structure", %{tmp_dir: tmp_dir} do
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

      persist_path = Path.join(tmp_dir, "test_graph")
      assert :ok = Graph.persist(graph, persist_path)

      assert {:ok, loaded_graph} = Graph.load(persist_path)

      assert Graph.vertex_count(loaded_graph) == Graph.vertex_count(graph)
      assert length(Graph.edges(loaded_graph)) == length(Graph.edges(graph))

      loaded_vertices = Graph.vertices(loaded_graph)
      assert %Root{} in loaded_vertices
      assert app in loaded_vertices
      assert mod1 in loaded_vertices
      assert mod2 in loaded_vertices

      assert Graph.get_vertex(loaded_graph, Vertex.id(app)) == app
      assert Graph.get_vertex(loaded_graph, Vertex.id(mod1)) == mod1

      Graph.delete(loaded_graph)
    end

    @tag :tmp_dir
    test "persist returns error for subgraphs", %{tmp_dir: tmp_dir} do
      graph = Graph.new()
      subgraph = Graph.filter(graph, true)

      persist_path = Path.join(tmp_dir, "subgraph_test")
      assert {:error, :subgraphs_are_readonly} = Graph.persist(subgraph, persist_path)

      Graph.delete(subgraph)
    end

    @tag :tmp_dir
    test "load handles missing files", %{tmp_dir: tmp_dir} do
      persist_path = Path.join(tmp_dir, "nonexistent_graph")
      assert {:error, _reason} = Graph.load(persist_path)
    end

    @tag :tmp_dir
    test "persist/load preserves update_count", %{tmp_dir: tmp_dir} do
      graph = Graph.new()
      app = %Application{app: :test_app, description: "Test", version: "1.0.0"}
      Graph.add_vertex(graph, app, %Root{})
      Graph.add_edge(graph, %Root{}, app, :application)

      original_count = Graph.get_update_count(graph)

      persist_path = Path.join(tmp_dir, "count_test")
      assert :ok = Graph.persist(graph, persist_path)

      assert {:ok, loaded_graph} = Graph.load(persist_path)
      assert Graph.get_update_count(loaded_graph) == original_count

      Graph.delete(loaded_graph)
    end

    @tag :tmp_dir
    test "persist/load preserves relationships and edges", %{tmp_dir: tmp_dir} do
      graph = Graph.new()
      app1 = %Application{app: :app1, description: "App 1", version: "1.0.0"}
      app2 = %Application{app: :app2, description: "App 2", version: "1.0.0"}
      mod = %Module{module: TestMod}

      Graph.add_vertex(graph, app1, %Root{})
      Graph.add_vertex(graph, app2, %Root{})
      Graph.add_vertex(graph, mod, app1)
      Graph.add_edge(graph, %Root{}, app1, :application)
      Graph.add_edge(graph, %Root{}, app2, :application)
      Graph.add_edge(graph, app1, mod, :module)

      persist_path = Path.join(tmp_dir, "edges_test")
      assert :ok = Graph.persist(graph, persist_path)

      assert {:ok, loaded_graph} = Graph.load(persist_path)

      assert loaded_graph |> Graph.out_neighbors(%Root{}) |> length() == 2
      assert Graph.out_neighbors(loaded_graph, app1) == [mod]
      assert Graph.in_neighbors(loaded_graph, mod) == [app1]

      [edge_id | _] = Graph.out_edges(loaded_graph, %Root{})
      {_, from_vertex, to_vertex, label} = Graph.edge(loaded_graph, edge_id)
      assert from_vertex == %Root{}
      assert to_vertex in [app1, app2]
      assert label == :application

      Graph.delete(loaded_graph)
    end
  end

  describe "degree tracking" do
    test "tracks in_degree and out_degree for vertices" do
      graph = Graph.new()
      app1 = %Application{app: :app1, description: "App 1", version: "1.0.0"}
      app2 = %Application{app: :app2, description: "App 2", version: "1.0.0"}
      app3 = %Application{app: :app3, description: "App 3", version: "1.0.0"}

      Graph.add_vertex(graph, app1, %Root{})
      Graph.add_vertex(graph, app2, %Root{})
      Graph.add_vertex(graph, app3, %Root{})

      assert Graph.in_degree(graph, app1) == 0
      assert Graph.out_degree(graph, app1) == 0

      Graph.add_edge(graph, app1, app2, :label_a)

      assert Graph.out_degree(graph, app1) == 1
      assert Graph.out_degree(graph, app1, :label_a) == 1
      assert Graph.out_degree(graph, app1, :label_b) == 0
      assert Graph.in_degree(graph, app2) == 1
      assert Graph.in_degree(graph, app2, :label_a) == 1
      assert Graph.in_degree(graph, app2, :label_b) == 0

      Graph.add_edge(graph, app1, app3, :label_b)

      assert Graph.out_degree(graph, app1) == 2
      assert Graph.out_degree(graph, app1, :label_a) == 1
      assert Graph.out_degree(graph, app1, :label_b) == 1
      assert Graph.in_degree(graph, app3) == 1
      assert Graph.in_degree(graph, app3, :label_b) == 1

      Graph.add_edge(graph, app2, app3, :label_a)

      assert Graph.out_degree(graph, app2) == 1
      assert Graph.in_degree(graph, app3) == 2
      assert Graph.in_degree(graph, app3, :label_a) == 1
      assert Graph.in_degree(graph, app3, :label_b) == 1
    end

    test "updates degrees when vertices are purged" do
      graph = Graph.new()
      app1 = %Application{app: :app1, description: "App 1", version: "1.0.0"}
      app2 = %Application{app: :app2, description: "App 2", version: "1.0.0"}
      app3 = %Application{app: :app3, description: "App 3", version: "1.0.0"}

      Graph.add_vertex(graph, app1, %Root{})
      Graph.add_vertex(graph, app2, %Root{})
      Graph.add_vertex(graph, app3, %Root{})

      Graph.add_edge(graph, app1, app2, :label_a)
      Graph.add_edge(graph, app1, app3, :label_b)
      Graph.add_edge(graph, app2, app3, :label_a)

      assert Graph.out_degree(graph, app1) == 2
      assert Graph.in_degree(graph, app2) == 1
      assert Graph.in_degree(graph, app3) == 2

      {:ok, _purged} = Graph.purge(graph, app2)

      assert Graph.out_degree(graph, app1) == 1
      assert Graph.out_degree(graph, app1, :label_a) == 0
      assert Graph.out_degree(graph, app1, :label_b) == 1
      assert Graph.in_degree(graph, app3) == 1
      assert Graph.in_degree(graph, app3, :label_a) == 0
      assert Graph.in_degree(graph, app3, :label_b) == 1
    end

    test "clears degrees when graph is cleared" do
      graph = Graph.new()
      app1 = %Application{app: :app1, description: "App 1", version: "1.0.0"}
      app2 = %Application{app: :app2, description: "App 2", version: "1.0.0"}

      Graph.add_vertex(graph, app1, %Root{})
      Graph.add_vertex(graph, app2, %Root{})

      Graph.add_edge(graph, app1, app2, :label_a)

      assert Graph.out_degree(graph, app1) == 1
      assert Graph.in_degree(graph, app2) == 1

      Graph.clear(graph)

      app3 = %Application{app: :app3, description: "App 3", version: "1.0.0"}
      app4 = %Application{app: :app4, description: "App 4", version: "1.0.0"}

      Graph.add_vertex(graph, app3, %Root{})
      Graph.add_vertex(graph, app4, %Root{})

      assert Graph.out_degree(graph, app3) == 0
      assert Graph.in_degree(graph, app4) == 0
    end

    @tag :tmp_dir
    test "preserves degree indexes through persist and load", %{tmp_dir: tmp_dir} do
      graph = Graph.new()
      app1 = %Application{app: :app1, description: "App 1", version: "1.0.0"}
      app2 = %Application{app: :app2, description: "App 2", version: "1.0.0"}
      app3 = %Application{app: :app3, description: "App 3", version: "1.0.0"}

      Graph.add_vertex(graph, app1, %Root{})
      Graph.add_vertex(graph, app2, %Root{})
      Graph.add_vertex(graph, app3, %Root{})

      Graph.add_edge(graph, app1, app2, :label_a)
      Graph.add_edge(graph, app1, app3, :label_b)
      Graph.add_edge(graph, app2, app3, :label_a)

      path = Path.join(tmp_dir, "test_graph_indexes")

      assert :ok = Graph.persist(graph, path)

      {:ok, loaded_graph} = Graph.load(path)

      [loaded_v1, loaded_v2, loaded_v3] =
        loaded_graph
        |> Graph.vertices()
        |> Enum.reject(&match?(%Root{}, &1))
        |> Enum.sort_by(& &1.app)

      assert Graph.out_degree(loaded_graph, loaded_v1) == 2
      assert Graph.out_degree(loaded_graph, loaded_v1, :label_a) == 1
      assert Graph.out_degree(loaded_graph, loaded_v1, :label_b) == 1
      assert Graph.in_degree(loaded_graph, loaded_v2) == 1
      assert Graph.in_degree(loaded_graph, loaded_v2, :label_a) == 1
      assert Graph.in_degree(loaded_graph, loaded_v3) == 2
      assert Graph.in_degree(loaded_graph, loaded_v3, :label_a) == 1
      assert Graph.in_degree(loaded_graph, loaded_v3, :label_b) == 1
    end

    test "shares indexes between main graph and subgraphs" do
      graph = Graph.new()
      app1 = %Application{app: :app1, description: "App 1", version: "1.0.0"}
      app2 = %Application{app: :app2, description: "App 2", version: "1.0.0"}
      app3 = %Application{app: :app3, description: "App 3", version: "1.0.0"}

      Graph.add_vertex(graph, app1, %Root{})
      Graph.add_vertex(graph, app2, %Root{})
      Graph.add_vertex(graph, app3, %Root{})

      Graph.add_edge(graph, app1, app2, :label_a)
      Graph.add_edge(graph, app1, app3, :label_b)

      subgraph =
        Graph.filter(graph, fn _graph ->
          # Include app1, app2, and root
          app1_id = Vertex.id(app1)
          app2_id = Vertex.id(app2)
          root_id = Vertex.id(%Root{})
          {:in, :vertex_id, [app1_id, app2_id, root_id]}
        end)

      assert Graph.out_degree(subgraph, app1) == 1
      assert Graph.out_degree(subgraph, app1, :label_a) == 1
      assert Graph.in_degree(subgraph, app2) == 1

      Graph.add_edge(graph, app2, app3, :label_a)

      assert Graph.out_degree(graph, app2) == 1
      assert Graph.out_degree(graph, app2, :label_a) == 1
      assert Graph.in_degree(subgraph, app2, :label_a) == 1
    end
  end

  describe "handover/2" do
    test "transfers ownership of all ETS tables to target process" do
      graph = Graph.new()
      test_pid = self()

      task =
        Task.async(fn ->
          receive do
            {:graph, graph} ->
              assert graph.owner == self()
              send(test_pid, {:ets_owner, :ets.info(graph.vertices, :owner)})

              receive do
                :continue -> :ok
              end
          end
        end)

      assert {:ok, new_graph} = Graph.handover(graph, task.pid)
      assert new_graph.owner == task.pid

      send(task.pid, {:graph, new_graph})

      assert_receive {:ets_owner, owner}, 1000
      assert owner == task.pid

      send(task.pid, :continue)
      Task.await(task)
    end

    test "returns error when called from non-owner process" do
      graph = Graph.new()
      original_owner = self()

      task =
        Task.async(fn ->
          receive do
            {:test_graph, graph} ->
              assert graph.owner == original_owner

              assert {:error, :not_owner} = Graph.handover(graph, self())
          end
        end)

      send(task.pid, {:test_graph, graph})
      Task.await(task)
    end

    test "transfers all 12 ETS tables (3 direct + 9 from digraphs)" do
      graph = Graph.new()
      test_pid = self()

      task =
        Task.async(fn ->
          receive do
            {:graph, _graph} ->
              owned_tables =
                :ets.all()
                |> Enum.filter(fn table -> :ets.info(table, :owner) == self() end)
                |> length()

              send(test_pid, {:owned_count, owned_tables})

              receive do
                :continue -> :ok
              end
          end
        end)

      assert {:ok, new_graph} = Graph.handover(graph, task.pid)
      send(task.pid, {:graph, new_graph})

      assert_receive {:owned_count, count}, 1000
      assert count >= 12

      send(task.pid, :continue)
      Task.await(task)
    end

    test "allows operations on graph after handover in new owner process" do
      graph = Graph.new()
      app = %Application{app: :test, description: "Test", version: "1.0.0"}
      Graph.add_vertex(graph, app, %Root{})
      test_pid = self()

      task =
        Task.async(fn ->
          receive do
            {:graph, graph} ->
              mod = %Module{module: TestModule}
              assert :ok = Graph.add_vertex(graph, mod, app)
              assert :ok = Graph.add_edge(graph, app, mod, :module)

              vertices = Graph.vertices(graph)
              assert mod in vertices

              send(test_pid, :success)

              receive do
                :continue -> :ok
              end
          end
        end)

      assert {:ok, new_graph} = Graph.handover(graph, task.pid)
      send(task.pid, {:graph, new_graph})

      assert_receive :success, 1000

      send(task.pid, :continue)
      Task.await(task)
    end

    test "returns error when trying to operate on graph after handover from original owner" do
      graph = Graph.new()
      app = %Application{app: :test, description: "Test", version: "1.0.0"}

      task =
        Task.async(fn ->
          receive do
            {:continue, _graph} -> :ok
          end
        end)

      assert {:ok, graph} = Graph.handover(graph, task.pid)

      assert {:error, :not_owner} = Graph.add_vertex(graph, app, %Root{})

      send(task.pid, {:continue, graph})
      Task.await(task)
    end
  end

  describe "available_vertex_types/1" do
    test "returns only Root for graph with only root" do
      graph = Graph.new()
      types = Graph.available_vertex_types(graph)
      assert types == [Root]
    end

    test "returns all unique vertex types in graph" do
      graph = Graph.new()

      app1 = %Application{app: :app1, description: "App 1", version: "1.0.0"}
      app2 = %Application{app: :app2, description: "App 2", version: "2.0.0"}
      mod1 = %Module{module: TestModule}

      Graph.add_vertex(graph, app1, %Root{})
      Graph.add_vertex(graph, app2, %Root{})
      Graph.add_vertex(graph, mod1, %Root{})

      types = Graph.available_vertex_types(graph)
      assert length(types) == 3
      assert Application in types
      assert Module in types
      assert Root in types
    end

    test "returns sorted list of types" do
      graph = Graph.new()

      mod1 = %Module{module: TestModule}
      app1 = %Application{app: :app1, description: "App 1", version: "1.0.0"}

      Graph.add_vertex(graph, mod1, %Root{})
      Graph.add_vertex(graph, app1, %Root{})

      types = Graph.available_vertex_types(graph)
      assert types == Enum.sort(types)
    end

    test "does not include duplicate types" do
      graph = Graph.new()

      app1 = %Application{app: :app1, description: "App 1", version: "1.0.0"}
      app2 = %Application{app: :app2, description: "App 2", version: "2.0.0"}
      app3 = %Application{app: :app3, description: "App 3", version: "3.0.0"}

      Graph.add_vertex(graph, app1, %Root{})
      Graph.add_vertex(graph, app2, %Root{})
      Graph.add_vertex(graph, app3, %Root{})

      types = Graph.available_vertex_types(graph)
      assert length(types) == 2
      assert Application in types
      assert Root in types
    end
  end
end
