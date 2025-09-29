defmodule Clarity.Vertex.Ash.DataLayerTest do
  use ExUnit.Case, async: true

  alias Ash.DataLayer.Ets
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.DataLayer

  describe "Clarity.Vertex protocol implementation for Ash.DataLayer" do
    setup do
      # Use a common Ash data layer for testing
      vertex = %DataLayer{data_layer: Ets}
      {:ok, vertex: vertex}
    end

    test "unique_id/1 returns correct unique identifier", %{vertex: vertex} do
      assert Vertex.unique_id(vertex) == "data_layer:Ash.DataLayer.Ets"
    end

    test "graph_id/1 returns correct graph identifier", %{vertex: vertex} do
      assert Vertex.graph_id(vertex) == "Ash.DataLayer.Ets"
    end

    test "graph_group/1 returns empty list", %{vertex: vertex} do
      assert Vertex.graph_group(vertex) == []
    end

    test "type_label/1 returns correct type label", %{vertex: vertex} do
      assert Vertex.type_label(vertex) == "Ash.DataLayer"
    end

    test "render_name/1 returns correct display name", %{vertex: vertex} do
      assert Vertex.render_name(vertex) == "Ash.DataLayer.Ets"
    end

    test "dot_shape/1 returns correct shape", %{vertex: vertex} do
      assert Vertex.dot_shape(vertex) == "cylinder"
    end

    test "markdown_overview/1 returns formatted overview", %{vertex: vertex} do
      overview = Vertex.markdown_overview(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "`Ash.DataLayer.Ets`"
    end

    test "source_location/1 returns SourceLocation from module", %{vertex: vertex} do
      source_location = Vertex.source_location(vertex)

      assert %Clarity.SourceLocation{} = source_location
      assert :erl_anno.is_anno(source_location.anno)
      assert source_location.application == :ash
      assert source_location.module == Ets

      file_path = Clarity.SourceLocation.file_path(source_location)
      if file_path, do: assert(String.ends_with?(file_path, "ash/lib/ash/data_layer/ets/ets.ex"))
    end
  end

  describe "DataLayer struct" do
    test "enforces required keys" do
      assert_raise ArgumentError, fn ->
        struct!(DataLayer, %{})
      end
    end

    test "creates struct with required data_layer field" do
      vertex = %DataLayer{data_layer: Ets}

      assert vertex.data_layer == Ets
    end
  end

  describe "markdown_overview with different data layers" do
    test "handles different data layer modules" do
      vertex = %DataLayer{data_layer: Ash.DataLayer.Mnesia}
      overview = Vertex.markdown_overview(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "`Ash.DataLayer.Mnesia`"
    end

    test "includes module documentation when available" do
      vertex = %DataLayer{data_layer: Ets}
      overview = Vertex.markdown_overview(vertex)
      overview_string = IO.iodata_to_binary(overview)

      # The overview should contain the module name at minimum
      assert overview_string =~ "`Ash.DataLayer.Ets`"
      # Module docs would be included if available via Code.fetch_docs
    end
  end
end
