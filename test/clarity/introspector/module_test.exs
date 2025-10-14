defmodule Clarity.Introspector.ModuleTest do
  use ExUnit.Case, async: true

  alias Clarity.Introspector.Module, as: ModuleIntrospector
  alias Clarity.Server.Worker
  alias Clarity.Vertex
  alias Clarity.Vertex.Module

  describe inspect(&ModuleIntrospector.introspect_vertex/2) do
    test "creates module vertices for application vertices" do
      graph = Clarity.Graph.new()
      app_vertex = %Vertex.Application{app: :clarity, description: "Clarity", version: "1.0.0"}

      {:ok, result} = ModuleIntrospector.introspect_vertex(app_vertex, graph)

      # Should contain specific modules we know exist in clarity app
      # Check that modules have version field set (either :unknown or string)
      module_vertices = result |> Enum.filter(&match?({:vertex, %Module{}}, &1)) |> Enum.map(&elem(&1, 1))

      assert Enum.any?(module_vertices, fn %Module{module: mod, version: version} ->
               mod == Module and is_integer(version)
             end)

      assert Enum.any?(module_vertices, fn %Module{module: mod, version: version} ->
               mod == Clarity.Server and is_integer(version)
             end)

      assert Enum.any?(module_vertices, fn %Module{module: mod, version: version} ->
               mod == Worker and is_integer(version)
             end)

      # Check edges are still created correctly
      module_vertex = Enum.find(module_vertices, &(&1.module == Module))
      assert {:edge, app_vertex, module_vertex, :module} in result
    end

    test "returns empty list for applications without modules" do
      graph = Clarity.Graph.new()
      app_vertex = %Vertex.Application{app: :nonexistent_app, description: "Test", version: "1.0.0"}

      assert {:ok, []} = ModuleIntrospector.introspect_vertex(app_vertex, graph)
    end

    test "extracts module version information" do
      graph = Clarity.Graph.new()
      app_vertex = %Vertex.Application{app: :kernel, description: "Kernel", version: "1.0.0"}

      {:ok, result} = ModuleIntrospector.introspect_vertex(app_vertex, graph)

      # Get a module vertex from the result
      module_vertices = result |> Enum.filter(&match?({:vertex, %Module{}}, &1)) |> Enum.map(&elem(&1, 1))

      # All module vertices should have a version field (either :unknown or string)
      assert Enum.all?(module_vertices, fn %Module{version: version} ->
               version == :unknown or is_integer(version)
             end)

      # At least one module should exist
      assert length(module_vertices) > 0
    end

    test "detects behaviours correctly" do
      graph = Clarity.Graph.new()
      app_vertex = %Vertex.Application{app: :clarity, description: "Clarity", version: "1.0.0"}

      {:ok, result} = ModuleIntrospector.introspect_vertex(app_vertex, graph)

      module_vertices = result |> Enum.filter(&match?({:vertex, %Module{}}, &1)) |> Enum.map(&elem(&1, 1))

      # Clarity.Introspector is a behaviour
      introspector_vertex = Enum.find(module_vertices, &(&1.module == Clarity.Introspector))
      assert introspector_vertex.behaviour? == true

      # Clarity.Server is not a behaviour
      server_vertex = Enum.find(module_vertices, &(&1.module == Clarity.Server))
      refute server_vertex.behaviour?
    end

    test "returns empty list for modules with no behaviours" do
      graph = Clarity.Graph.new()
      module_vertex = %Module{module: Clarity.Config, version: :unknown, behaviour?: false}

      assert {:ok, []} = ModuleIntrospector.introspect_vertex(module_vertex, graph)
    end

    test "returns empty list when behaviours are filtered out by config" do
      graph = Clarity.Graph.new()
      module_vertex = %Module{module: Clarity.Server, version: :unknown, behaviour?: false}

      assert {:ok, []} = ModuleIntrospector.introspect_vertex(module_vertex, graph)
    end

    test "returns unmet dependencies when behaviour module not in graph" do
      graph = Clarity.Graph.new()
      root = %Vertex.Root{}
      module_vertex = %Module{module: ModuleIntrospector, version: :unknown, behaviour?: true}

      Clarity.Graph.add_vertex(graph, module_vertex, root)

      assert {:error, :unmet_dependencies} =
               ModuleIntrospector.introspect_vertex(module_vertex, graph)
    end

    test "creates edge when behaviour module is in graph" do
      graph = Clarity.Graph.new()
      root = %Vertex.Root{}
      module_vertex = %Module{module: ModuleIntrospector, version: :unknown, behaviour?: true}
      behaviour_vertex = %Module{module: Clarity.Introspector, version: :unknown, behaviour?: true}

      Clarity.Graph.add_vertex(graph, module_vertex, root)
      Clarity.Graph.add_vertex(graph, behaviour_vertex, root)

      assert {:ok, [{:edge, ^module_vertex, ^behaviour_vertex, :behaviour}]} =
               ModuleIntrospector.introspect_vertex(module_vertex, graph)
    end
  end

  describe "protocol implementation detection" do
    test "returns empty for module with no protocol implementation" do
      graph = Clarity.Graph.new()
      module_vertex = %Module{module: Clarity.Server, version: :unknown, behaviour?: false}

      assert {:ok, []} = ModuleIntrospector.introspect_vertex(module_vertex, graph)
    end

    test "creates edges when both protocol and for modules are in graph" do
      graph = Clarity.Graph.new()
      root = %Vertex.Root{}
      impl_module = Clarity.Vertex.Clarity.Vertex.Module
      module_vertex = %Module{module: impl_module, version: :unknown, behaviour?: false}
      protocol_vertex = %Module{module: Vertex, version: :unknown, behaviour?: true}
      for_vertex = %Module{module: Module, version: :unknown, behaviour?: false}

      Clarity.Graph.add_vertex(graph, module_vertex, root)
      Clarity.Graph.add_vertex(graph, protocol_vertex, root)
      Clarity.Graph.add_vertex(graph, for_vertex, root)

      {:ok, edges} = ModuleIntrospector.introspect_vertex(module_vertex, graph)

      protocol_edge = Enum.find(edges, &match?({:edge, _, _, :protocol_implementation}, &1))
      assert {:edge, ^protocol_vertex, ^module_vertex, :protocol_implementation} = protocol_edge

      for_edge = Enum.find(edges, &match?({:edge, _, _, :protocol_subject}, &1))
      assert {:edge, ^module_vertex, ^for_vertex, :protocol_subject} = for_edge
    end

    test "returns unmet dependencies when protocol module not in graph" do
      graph = Clarity.Graph.new()
      root = %Vertex.Root{}
      impl_module = Clarity.Vertex.Clarity.Vertex.Module
      module_vertex = %Module{module: impl_module, version: :unknown, behaviour?: false}
      for_vertex = %Module{module: Module, version: :unknown, behaviour?: false}

      Clarity.Graph.add_vertex(graph, module_vertex, root)
      Clarity.Graph.add_vertex(graph, for_vertex, root)

      assert {:error, :unmet_dependencies} =
               ModuleIntrospector.introspect_vertex(module_vertex, graph)
    end

    test "returns unmet dependencies when for module not in graph" do
      graph = Clarity.Graph.new()
      root = %Vertex.Root{}
      impl_module = Clarity.Vertex.Clarity.Vertex.Module
      module_vertex = %Module{module: impl_module, version: :unknown, behaviour?: false}
      protocol_vertex = %Module{module: Vertex, version: :unknown, behaviour?: true}

      Clarity.Graph.add_vertex(graph, module_vertex, root)
      Clarity.Graph.add_vertex(graph, protocol_vertex, root)

      assert {:error, :unmet_dependencies} =
               ModuleIntrospector.introspect_vertex(module_vertex, graph)
    end

    test "returns empty when protocol is filtered out by config" do
      graph = Clarity.Graph.new()
      module_vertex = %Module{module: Inspect.Clarity.Graph, version: :unknown, behaviour?: false}

      assert {:ok, []} = ModuleIntrospector.introspect_vertex(module_vertex, graph)
    end

    test "creates behaviour, protocol, and for edges" do
      graph = Clarity.Graph.new()
      root = %Vertex.Root{}
      impl_module = Clarity.Vertex.Clarity.Vertex.Module
      module_vertex = %Module{module: impl_module, version: :unknown, behaviour?: false}
      protocol_vertex = %Module{module: Vertex, version: :unknown, behaviour?: true}
      for_vertex = %Module{module: Module, version: :unknown, behaviour?: false}

      Clarity.Graph.add_vertex(graph, module_vertex, root)
      Clarity.Graph.add_vertex(graph, protocol_vertex, root)
      Clarity.Graph.add_vertex(graph, for_vertex, root)

      {:ok, edges} = ModuleIntrospector.introspect_vertex(module_vertex, graph)

      assert length(edges) == 3

      behaviour_edge = Enum.find(edges, &match?({:edge, _, _, :behaviour}, &1))
      assert {:edge, ^module_vertex, ^protocol_vertex, :behaviour} = behaviour_edge

      protocol_edge = Enum.find(edges, &match?({:edge, _, _, :protocol_implementation}, &1))
      assert {:edge, ^protocol_vertex, ^module_vertex, :protocol_implementation} = protocol_edge

      for_edge = Enum.find(edges, &match?({:edge, _, _, :protocol_subject}, &1))
      assert {:edge, ^module_vertex, ^for_vertex, :protocol_subject} = for_edge
    end
  end

  describe "cache rehydration" do
    test "purges modules that were removed" do
      graph = Clarity.Graph.new()
      root = %Vertex.Root{}
      app_vertex = %Vertex.Application{app: :clarity, description: "Clarity", version: "1.0.0"}

      Clarity.Graph.add_vertex(graph, root, root)
      Clarity.Graph.add_vertex(graph, app_vertex, root)

      # Create cached module vertex for a module that doesn't exist
      cached_module = %Module{
        module: NonexistentRemovedModule,
        version: 123,
        behaviour?: false
      }

      Clarity.Graph.add_vertex(graph, cached_module, app_vertex)
      Clarity.Graph.add_edge(graph, app_vertex, cached_module, :module)

      {:ok, result} = ModuleIntrospector.introspect_vertex(app_vertex, graph)

      # Should have purge entry for removed module
      purge_entries = Enum.filter(result, &match?({:purge, %Module{}}, &1))

      assert Enum.any?(purge_entries, fn {:purge, vertex} ->
               vertex.module == NonexistentRemovedModule
             end)
    end

    test "purges and re-adds modules with changed versions" do
      graph = Clarity.Graph.new()
      root = %Vertex.Root{}
      app_vertex = %Vertex.Application{app: :clarity, description: "Clarity", version: "1.0.0"}

      Clarity.Graph.add_vertex(graph, root, root)
      Clarity.Graph.add_vertex(graph, app_vertex, root)

      # Create cached module with old version
      cached_module = %Module{
        module: Clarity.Server,
        version: 999,
        behaviour?: false
      }

      Clarity.Graph.add_vertex(graph, cached_module, app_vertex)
      Clarity.Graph.add_edge(graph, app_vertex, cached_module, :module)

      {:ok, result} = ModuleIntrospector.introspect_vertex(app_vertex, graph)

      # Should have purge entry for old version
      purge_entries = Enum.filter(result, &match?({:purge, %Module{}}, &1))

      assert Enum.any?(purge_entries, fn {:purge, vertex} ->
               vertex.module == Clarity.Server and vertex.version == 999
             end)

      # Should have add entry for new version
      add_vertices = Enum.filter(result, &match?({:vertex, %Module{}}, &1))

      new_module =
        Enum.find(add_vertices, fn {:vertex, vertex} ->
          vertex.module == Clarity.Server
        end)

      assert new_module
      {:vertex, new_module_vertex} = new_module
      assert new_module_vertex.version != 999
    end

    test "skips modules with unchanged versions" do
      graph = Clarity.Graph.new()
      root = %Vertex.Root{}
      app_vertex = %Vertex.Application{app: :clarity, description: "Clarity", version: "1.0.0"}

      Clarity.Graph.add_vertex(graph, root, root)
      Clarity.Graph.add_vertex(graph, app_vertex, root)

      # Get current version for Clarity.Server
      current_version =
        case Clarity.Server.module_info(:attributes)[:vsn] do
          nil -> :unknown
          [version] -> version
        end

      # Create cached module with same version
      cached_module = %Module{
        module: Clarity.Server,
        version: current_version,
        behaviour?: false
      }

      Clarity.Graph.add_vertex(graph, cached_module, app_vertex)
      Clarity.Graph.add_edge(graph, app_vertex, cached_module, :module)

      {:ok, result} = ModuleIntrospector.introspect_vertex(app_vertex, graph)

      # Should not have purge or add entries for Clarity.Server (unchanged)
      server_purges =
        Enum.filter(result, fn
          {:purge, %Module{module: Clarity.Server}} -> true
          _ -> false
        end)

      server_adds =
        Enum.filter(result, fn
          {:vertex, %Module{module: Clarity.Server}} -> true
          _ -> false
        end)

      assert server_purges == []
      assert server_adds == []
    end

    test "adds new modules" do
      graph = Clarity.Graph.new()
      root = %Vertex.Root{}
      app_vertex = %Vertex.Application{app: :clarity, description: "Clarity", version: "1.0.0"}

      Clarity.Graph.add_vertex(graph, root, root)
      Clarity.Graph.add_vertex(graph, app_vertex, root)

      # Don't add any cached modules to graph

      {:ok, result} = ModuleIntrospector.introspect_vertex(app_vertex, graph)

      # All current modules should have add entries
      clarity_modules = Application.spec(:clarity, :modules) || []
      add_vertices = Enum.filter(result, &match?({:vertex, %Module{}}, &1))

      assert length(add_vertices) == length(clarity_modules)

      # No purge entries since graph was empty
      purge_entries = Enum.filter(result, &match?({:purge, %Module{}}, &1))
      assert purge_entries == []
    end
  end
end
