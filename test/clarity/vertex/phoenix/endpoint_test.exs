defmodule Clarity.Vertex.Phoenix.EndpointTest do
  use Clarity.Test.ConnCase, async: true

  alias Clarity.Vertex
  alias Clarity.Vertex.Phoenix.Endpoint

  setup do
    vertex = %Endpoint{endpoint: DemoWeb.Endpoint}
    {:ok, vertex: vertex}
  end

  describe "Clarity.Vertex protocol implementation for Phoenix.Endpoint" do
    test "unique_id/1 returns correct unique identifier", %{vertex: vertex} do
      assert Vertex.unique_id(vertex) == "endpoint:DemoWeb.Endpoint"
    end

    test "graph_id/1 returns correct graph identifier", %{vertex: vertex} do
      assert Vertex.graph_id(vertex) == "DemoWeb.Endpoint"
    end

    test "graph_group/1 returns empty list", %{vertex: vertex} do
      assert Vertex.graph_group(vertex) == []
    end

    test "type_label/1 returns correct type label", %{vertex: vertex} do
      assert Vertex.type_label(vertex) == "Clarity.Vertex.Phoenix.Endpoint"
    end

    test "render_name/1 returns correct display name", %{vertex: vertex} do
      assert Vertex.render_name(vertex) == "DemoWeb.Endpoint"
    end

    test "dot_shape/1 returns correct shape", %{vertex: vertex} do
      assert Vertex.dot_shape(vertex) == "foo"
    end

    test "markdown_overview/1 returns formatted overview", %{vertex: vertex} do
      overview = Vertex.markdown_overview(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "`DemoWeb.Endpoint`"
      assert overview_string =~ "URL: "
      # The URL would be provided by DemoWeb.Endpoint.url()
    end

    test "source_location/1 returns SourceLocation from module", %{vertex: vertex} do
      source_location = Vertex.source_location(vertex)

      assert %Clarity.SourceLocation{} = source_location
      assert :erl_anno.is_anno(source_location.anno)
      assert source_location.application == :clarity
      assert source_location.module == DemoWeb.Endpoint

      file_path = Clarity.SourceLocation.file_path(source_location)
      if file_path, do: assert(String.ends_with?(file_path, "dev/demo_web/endpoint.ex"))
    end
  end

  describe "Endpoint struct" do
    test "enforces required keys" do
      assert_raise ArgumentError, fn ->
        struct!(Endpoint, %{})
      end
    end

    test "creates struct with required endpoint field" do
      vertex = %Endpoint{endpoint: DemoWeb.Endpoint}

      assert vertex.endpoint == DemoWeb.Endpoint
    end
  end

  describe "markdown_overview with different endpoints" do
    test "calls url/0 function on endpoint module", %{vertex: vertex} do
      overview = Vertex.markdown_overview(vertex)
      overview_string = IO.iodata_to_binary(overview)

      # Should include the module name
      assert overview_string =~ "`DemoWeb.Endpoint`"
      # Should include URL label
      assert overview_string =~ "URL: "
      # The actual URL would depend on DemoWeb.Endpoint.url() implementation
    end
  end
end
