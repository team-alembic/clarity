defmodule Clarity.Vertex.Spark.ExtensionTest do
  use ExUnit.Case, async: true

  alias Ash.Resource.Dsl
  alias Clarity.Vertex
  alias Clarity.Vertex.Spark.Extension

  setup do
    vertex = %Extension{extension: Dsl}
    {:ok, vertex: vertex}
  end

  describe inspect(&Vertex.id/1) do
    test "returns correct unique identifier", %{vertex: vertex} do
      assert Vertex.id(vertex) == "spark-extension:ash-resource-dsl"
    end
  end

  describe inspect(&Vertex.type_label/1) do
    test "returns correct type label", %{vertex: vertex} do
      assert Vertex.type_label(vertex) == "Spark Extension"
    end
  end

  describe inspect(&Vertex.name/1) do
    test "returns correct display name", %{vertex: vertex} do
      assert Vertex.name(vertex) == "Ash.Resource.Dsl"
    end
  end

  describe inspect(&Clarity.Vertex.GraphShapeProvider.shape/1) do
    test "returns correct shape", %{vertex: vertex} do
      assert Vertex.GraphShapeProvider.shape(vertex) == "component"
    end
  end

  describe inspect(&Clarity.Vertex.ModuleProvider.module/1) do
    test "returns the extension module", %{vertex: vertex} do
      assert Vertex.ModuleProvider.module(vertex) == Dsl
    end
  end

  describe inspect(&Clarity.Vertex.SourceLocationProvider.source_location/1) do
    test "returns SourceLocation from module", %{vertex: vertex} do
      source_location = Vertex.SourceLocationProvider.source_location(vertex)

      assert %Clarity.SourceLocation{} = source_location
      assert :erl_anno.is_anno(source_location.anno)
      assert source_location.application == :ash
      assert source_location.module == Dsl

      file_path = Clarity.SourceLocation.file_path(source_location)
      if file_path, do: assert(String.ends_with?(file_path, "ash/lib/ash/resource/dsl.ex"))
    end
  end

  describe inspect(&Clarity.Vertex.TooltipProvider.tooltip/1) do
    test "returns formatted overview", %{vertex: vertex} do
      overview = Vertex.TooltipProvider.tooltip(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "`Ash.Resource.Dsl`"
    end
  end
end
