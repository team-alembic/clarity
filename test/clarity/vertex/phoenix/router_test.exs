defmodule Clarity.Vertex.Phoenix.RouterTest do
  use ExUnit.Case, async: true

  alias Clarity.Vertex
  alias Clarity.Vertex.Phoenix.Router

  describe "Clarity.Vertex protocol implementation for Phoenix.Router" do
    setup do
      vertex = %Router{router: DemoWeb.Router}
      {:ok, vertex: vertex}
    end

    test "unique_id/1 returns correct unique identifier", %{vertex: vertex} do
      assert Vertex.unique_id(vertex) == "router:DemoWeb.Router"
    end

    test "graph_id/1 returns correct graph identifier", %{vertex: vertex} do
      assert Vertex.graph_id(vertex) == "DemoWeb.Router"
    end

    test "graph_group/1 returns empty list", %{vertex: vertex} do
      assert Vertex.graph_group(vertex) == []
    end

    test "type_label/1 returns correct type label", %{vertex: vertex} do
      assert Vertex.type_label(vertex) == "Clarity.Vertex.Phoenix.Router"
    end

    test "render_name/1 returns correct display name", %{vertex: vertex} do
      assert Vertex.render_name(vertex) == "DemoWeb.Router"
    end

    test "dot_shape/1 returns correct shape", %{vertex: vertex} do
      assert Vertex.dot_shape(vertex) == "foo"
    end

    test "markdown_overview/1 returns formatted overview with routes table", %{vertex: vertex} do
      overview = Vertex.markdown_overview(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "`DemoWeb.Router`"
      assert overview_string =~ "| Name | Method | Path | Plug | Action |"
      assert overview_string =~ "| ---- | ------ | ---- | ---------- | ------ |"
      assert overview_string =~ "| page_path | GET | / | Phoenix.LiveView.Plug | :page |"
      assert overview_string =~ "| page_path | GET | /:vertex/:content | Phoenix.LiveView.Plug | :page |"
    end

    test "source_location/1 returns SourceLocation from module", %{vertex: vertex} do
      source_location = Vertex.source_location(vertex)

      assert %Clarity.SourceLocation{} = source_location
      assert :erl_anno.is_anno(source_location.anno)
      assert source_location.application == :clarity
      assert source_location.module == DemoWeb.Router

      file_path = Clarity.SourceLocation.file_path(source_location)
      if file_path, do: assert(String.ends_with?(file_path, "dev/demo_web/router.ex"))
    end
  end

  describe "Router struct" do
    test "enforces required keys" do
      assert_raise ArgumentError, fn ->
        struct!(Router, %{})
      end
    end

    test "creates struct with required router field" do
      vertex = %Router{router: DemoWeb.Router}

      assert vertex.router == DemoWeb.Router
    end
  end

  describe "markdown_overview with different routers" do
    test "calls __routes__/0 function on router module" do
      vertex = %Router{router: DemoWeb.Router}
      overview = Vertex.markdown_overview(vertex)
      overview_string = IO.iodata_to_binary(overview)

      # Should include the module name
      assert overview_string =~ "`DemoWeb.Router`"
      # Should include routes table headers
      assert overview_string =~ "| Name | Method | Path | Plug | Action |"
      # Should include the specific routes
      assert overview_string =~ "| page_path | GET | / |"
      assert overview_string =~ "| page_path | GET | /:vertex/:content |"
    end
  end
end
