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
end
