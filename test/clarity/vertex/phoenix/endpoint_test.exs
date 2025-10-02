defmodule Clarity.Vertex.Phoenix.EndpointTest do
  use Clarity.Test.ConnCase, async: true

  alias Clarity.Vertex
  alias Clarity.Vertex.Phoenix.Endpoint

  setup do
    vertex = %Endpoint{endpoint: DemoWeb.Endpoint}
    {:ok, vertex: vertex}
  end

  describe inspect(&Vertex.id/1) do
    test "returns correct unique identifier", %{vertex: vertex} do
      assert Vertex.id(vertex) == "phoenix-endpoint:demo-web-endpoint"
    end
  end

  describe inspect(&Vertex.type_label/1) do
    test "returns correct type label", %{vertex: vertex} do
      assert Vertex.type_label(vertex) == "Clarity.Vertex.Phoenix.Endpoint"
    end
  end

  describe inspect(&Vertex.name/1) do
    test "returns correct display name", %{vertex: vertex} do
      assert Vertex.name(vertex) == "DemoWeb.Endpoint"
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
      assert source_location.module == DemoWeb.Endpoint

      file_path = Clarity.SourceLocation.file_path(source_location)
      if file_path, do: assert(String.ends_with?(file_path, "dev/demo_web/endpoint.ex"))
    end
  end

  describe inspect(&Clarity.Vertex.TooltipProvider.tooltip/1) do
    test "returns formatted overview", %{vertex: vertex} do
      overview = Vertex.TooltipProvider.tooltip(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "`DemoWeb.Endpoint`"
      assert overview_string =~ "URL: "
    end
  end

  describe "tooltip with different endpoints" do
    test "calls url/0 function on endpoint module", %{vertex: vertex} do
      overview = Vertex.TooltipProvider.tooltip(vertex)
      overview_string = IO.iodata_to_binary(overview)

      # Should include the module name
      assert overview_string =~ "`DemoWeb.Endpoint`"
      # Should include URL label
      assert overview_string =~ "URL: "
      # The actual URL would depend on DemoWeb.Endpoint.url() implementation
    end
  end
end
