defmodule Clarity.Vertex.ModuleTest do
  use ExUnit.Case, async: true

  alias Clarity.Vertex
  alias Clarity.Vertex.Module

  describe "Clarity.Vertex protocol implementation for Module" do
    setup do
      vertex = %Module{module: Clarity.Server}
      {:ok, vertex: vertex}
    end

    test "unique_id/1 returns correct unique identifier with version", %{vertex: vertex} do
      assert Vertex.unique_id(vertex) == "module:Clarity.Server:unknown"
    end

    test "graph_id/1 returns module name as string", %{vertex: vertex} do
      assert Vertex.graph_id(vertex) == "Clarity.Server"
    end

    test "graph_group/1 returns empty list", %{vertex: vertex} do
      assert Vertex.graph_group(vertex) == []
    end

    test "type_label/1 returns correct type label", %{vertex: vertex} do
      assert Vertex.type_label(vertex) == "Module"
    end

    test "render_name/1 returns module name as string", %{vertex: vertex} do
      assert Vertex.render_name(vertex) == "Clarity.Server"
    end

    test "dot_shape/1 returns box shape", %{vertex: vertex} do
      assert Vertex.dot_shape(vertex) == "box"
    end

    test "markdown_overview/1 returns formatted module name", %{vertex: vertex} do
      assert vertex |> Vertex.markdown_overview() |> IO.iodata_to_binary() == "`Clarity.Server`"
    end
  end

  describe "Module struct" do
    test "enforces required keys" do
      assert_raise ArgumentError, fn ->
        struct!(Module, %{})
      end
    end

    test "creates struct with required module field and defaults version to :unknown" do
      vertex = %Module{module: String}

      assert vertex.module == String
      assert vertex.version == :unknown
    end

    test "works with any module atom" do
      vertex = %Module{module: GenServer, version: "1.2.3"}

      assert vertex.module == GenServer
      assert vertex.version == "1.2.3"
      assert Vertex.unique_id(vertex) == "module:GenServer:1.2.3"
      assert Vertex.render_name(vertex) == "GenServer"
    end
  end
end
