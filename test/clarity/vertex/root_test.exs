defmodule Clarity.Vertex.RootTest do
  use ExUnit.Case, async: true

  alias Clarity.Vertex
  alias Clarity.Vertex.Root

  describe "Clarity.Vertex protocol implementation for Root" do
    setup do
      vertex = %Root{}
      {:ok, vertex: vertex}
    end

    test "unique_id/1 returns correct unique identifier", %{vertex: vertex} do
      assert Vertex.unique_id(vertex) == "root"
    end

    test "graph_id/1 returns correct graph identifier", %{vertex: vertex} do
      assert Vertex.graph_id(vertex) == "root"
    end

    test "graph_group/1 returns empty list", %{vertex: vertex} do
      assert Vertex.graph_group(vertex) == []
    end

    test "type_label/1 returns correct type label", %{vertex: vertex} do
      assert Vertex.type_label(vertex) == inspect(Root)
    end

    test "render_name/1 returns correct display name", %{vertex: vertex} do
      assert Vertex.render_name(vertex) == "Root"
    end

    test "dot_shape/1 returns correct shape", %{vertex: vertex} do
      assert Vertex.dot_shape(vertex) == "point"
    end

    test "markdown_overview/1 returns empty list", %{vertex: vertex} do
      assert Vertex.markdown_overview(vertex) == []
    end
  end

  describe "Root struct" do
    test "creates empty struct" do
      vertex = %Root{}
      assert vertex == %Root{}
    end
  end
end
