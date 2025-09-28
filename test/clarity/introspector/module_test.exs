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
               mod == Module and (version == :unknown or is_binary(version))
             end)

      assert Enum.any?(module_vertices, fn %Module{module: mod, version: version} ->
               mod == Clarity.Server and (version == :unknown or is_binary(version))
             end)

      assert Enum.any?(module_vertices, fn %Module{module: mod, version: version} ->
               mod == Worker and (version == :unknown or is_binary(version))
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
               version == :unknown or is_binary(version)
             end)

      # At least one module should exist
      assert length(module_vertices) > 0
    end
  end
end
