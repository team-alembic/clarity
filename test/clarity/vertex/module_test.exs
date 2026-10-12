defmodule Clarity.Vertex.ModuleTest do
  use ExUnit.Case, async: true

  alias Clarity.Vertex
  alias Clarity.Vertex.Module

  setup do
    vertex = %Module{module: Clarity.Server}
    {:ok, vertex: vertex}
  end

  describe inspect(&Vertex.id/1) do
    test "returns correct unique identifier with version", %{vertex: vertex} do
      assert Vertex.id(vertex) == "module:clarity-server:unknown"
    end
  end

  describe inspect(&Vertex.type_label/1) do
    test "returns correct type label", %{vertex: vertex} do
      assert Vertex.type_label(vertex) == "Module"
    end
  end

  describe inspect(&Vertex.name/1) do
    test "returns module name as string", %{vertex: vertex} do
      assert Vertex.name(vertex) == "Clarity.Server"
    end
  end

  describe inspect(&Clarity.Vertex.GraphGroupProvider.graph_group/1) do
    test "returns empty list", %{vertex: vertex} do
      assert Vertex.GraphGroupProvider.graph_group(vertex) == []
    end
  end

  describe inspect(&Clarity.Vertex.GraphShapeProvider.shape/1) do
    test "returns box shape", %{vertex: vertex} do
      assert Vertex.GraphShapeProvider.shape(vertex) == "box"
    end
  end

  describe inspect(&Clarity.Vertex.TooltipProvider.tooltip/1) do
    test "returns formatted module name", %{vertex: vertex} do
      assert vertex |> Vertex.TooltipProvider.tooltip() |> IO.iodata_to_binary() == "`Clarity.Server`"
    end
  end

  describe "Clarity.Vertex.HintProvider" do
    test "flags behaviours", %{vertex: vertex} do
      assert Vertex.HintProvider.icon(vertex) == :module
      assert Vertex.HintProvider.badges(vertex) == []
      assert Vertex.HintProvider.badges(%{vertex | behaviour?: true}) == ["behaviour"]
    end
  end

  describe inspect(&Module.version/1) do
    test "is the module's vsn attribute" do
      assert Module.version(Enum) == hd(Enum.module_info(:attributes)[:vsn])
    end
  end

  describe inspect(&Module.lookup/2) do
    test "finds the vertex for the module's current version" do
      graph = Clarity.Graph.new()
      vertex = %Module{module: Enum, version: Module.version(Enum)}
      Clarity.Graph.add_vertex(graph, vertex, %Vertex.Root{})

      assert Module.lookup(graph, Enum) == vertex
    end

    test "is nil when the graph has another version" do
      graph = Clarity.Graph.new()
      Clarity.Graph.add_vertex(graph, %Module{module: Enum, version: :unknown}, %Vertex.Root{})

      assert Module.lookup(graph, Enum) == nil
    end

    test "is nil for a module that can't be loaded" do
      assert Module.lookup(Clarity.Graph.new(), DoesNotExist.Anywhere) == nil
    end
  end
end
