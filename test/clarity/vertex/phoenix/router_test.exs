defmodule Clarity.Vertex.Phoenix.RouterTest do
  use ExUnit.Case, async: true

  alias Clarity.Vertex
  alias Clarity.Vertex.Phoenix.Router

  setup do
    vertex = %Router{router: DemoWeb.Router}
    {:ok, vertex: vertex}
  end

  describe inspect(&Vertex.id/1) do
    test "returns correct unique identifier", %{vertex: vertex} do
      assert Vertex.id(vertex) == "phoenix-router:demo-web-router"
    end
  end

  describe inspect(&Vertex.type_label/1) do
    test "returns correct type label", %{vertex: vertex} do
      assert Vertex.type_label(vertex) == "Clarity.Vertex.Phoenix.Router"
    end
  end

  describe inspect(&Vertex.name/1) do
    test "returns correct display name", %{vertex: vertex} do
      assert Vertex.name(vertex) == "DemoWeb.Router"
    end
  end

  describe inspect(&Clarity.Vertex.GraphGroupProvider.graph_group/1) do
    test "returns empty list", %{vertex: vertex} do
      assert Vertex.GraphGroupProvider.graph_group(vertex) == []
    end
  end

  describe inspect(&Clarity.Vertex.GraphShapeProvider.shape/1) do
    test "returns correct shape", %{vertex: vertex} do
      assert Vertex.GraphShapeProvider.shape(vertex) == "foo"
    end
  end

  describe inspect(&Clarity.Vertex.SourceLocationProvider.source_location/1) do
    test "returns SourceLocation from module", %{vertex: vertex} do
      source_location = Vertex.SourceLocationProvider.source_location(vertex)

      assert %Clarity.SourceLocation{} = source_location
      assert :erl_anno.is_anno(source_location.anno)
      assert source_location.application == :clarity
      assert source_location.module == DemoWeb.Router

      file_path = Clarity.SourceLocation.file_path(source_location)
      if file_path, do: assert(String.ends_with?(file_path, "dev/demo_web/router.ex"))
    end
  end

  describe inspect(&Clarity.Vertex.TooltipProvider.tooltip/1) do
    test "returns formatted overview with routes table", %{vertex: vertex} do
      overview = Vertex.TooltipProvider.tooltip(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "`DemoWeb.Router`"
      assert overview_string =~ "| Name | Method | Path | Plug | Action |"
      assert overview_string =~ "| ---- | ------ | ---- | ---------- | ------ |"
      assert overview_string =~ "| page_path | GET | / | Phoenix.LiveView.Plug | :root |"
      assert overview_string =~ "| page_path | GET | /:lens | Phoenix.LiveView.Plug | :lens |"
      assert overview_string =~ "| page_path | GET | /:lens/:vertex | Phoenix.LiveView.Plug | :vertex |"
      assert overview_string =~ "| page_path | GET | /:lens/:vertex/:content | Phoenix.LiveView.Plug | :page |"
    end
  end

  describe "tooltip with different routers" do
    test "calls __routes__/0 function on router module" do
      vertex = %Router{router: DemoWeb.Router}
      overview = Vertex.TooltipProvider.tooltip(vertex)
      overview_string = IO.iodata_to_binary(overview)

      # Should include the module name
      assert overview_string =~ "`DemoWeb.Router`"
      # Should include routes table headers
      assert overview_string =~ "| Name | Method | Path | Plug | Action |"
      # Should include the specific routes
      assert overview_string =~ "| page_path | GET | / |"
      assert overview_string =~ "| page_path | GET | /:lens |"
      assert overview_string =~ "| page_path | GET | /:lens/:vertex |"
      assert overview_string =~ "| page_path | GET | /:lens/:vertex/:content |"
    end
  end
end
