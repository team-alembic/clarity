defmodule Clarity.Vertex.RootTest do
  use ExUnit.Case, async: true

  alias Clarity.Vertex
  alias Clarity.Vertex.Root

  setup do
    vertex = %Root{}
    {:ok, vertex: vertex}
  end

  describe inspect(&Vertex.id/1) do
    test "returns correct unique identifier", %{vertex: vertex} do
      assert Vertex.id(vertex) == "root"
    end
  end

  describe inspect(&Vertex.type_label/1) do
    test "returns correct type label", %{vertex: vertex} do
      assert Vertex.type_label(vertex) == "Root"
    end
  end

  describe inspect(&Vertex.name/1) do
    test "returns correct display name", %{vertex: vertex} do
      assert Vertex.name(vertex) == "Root"
    end
  end

  describe inspect(&Clarity.Vertex.GraphGroupProvider.graph_group/1) do
    test "returns empty list", %{vertex: vertex} do
      assert Vertex.GraphGroupProvider.graph_group(vertex) == []
    end
  end

  describe inspect(&Clarity.Vertex.GraphShapeProvider.shape/1) do
    test "returns correct shape", %{vertex: vertex} do
      assert Vertex.GraphShapeProvider.shape(vertex) == "point"
    end
  end

  describe inspect(&Clarity.Vertex.TooltipProvider.tooltip/1) do
    test "returns nil", %{vertex: vertex} do
      assert Vertex.TooltipProvider.tooltip(vertex) == nil
    end
  end
end
