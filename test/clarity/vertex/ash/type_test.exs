defmodule Clarity.Vertex.Ash.TypeTest do
  use ExUnit.Case, async: true

  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Type

  setup do
    vertex = %Type{type: Ash.Type.String}
    {:ok, vertex: vertex}
  end

  describe inspect(&Vertex.id/1) do
    test "returns correct unique identifier", %{vertex: vertex} do
      assert Vertex.id(vertex) == "ash-type:ash-type-string"
    end
  end

  describe inspect(&Vertex.type_label/1) do
    test "returns correct type label", %{vertex: vertex} do
      assert Vertex.type_label(vertex) == "Ash.Type"
    end
  end

  describe inspect(&Vertex.name/1) do
    test "returns correct display name", %{vertex: vertex} do
      assert Vertex.name(vertex) == "Ash.Type.String"
    end
  end

  describe inspect(&Clarity.Vertex.GraphGroupProvider.graph_group/1) do
    test "returns empty list", %{vertex: vertex} do
      assert Vertex.GraphGroupProvider.graph_group(vertex) == []
    end
  end

  describe inspect(&Clarity.Vertex.GraphShapeProvider.shape/1) do
    test "returns correct shape", %{vertex: vertex} do
      assert Vertex.GraphShapeProvider.shape(vertex) == "plain"
    end
  end

  describe inspect(&Clarity.Vertex.SourceLocationProvider.source_location/1) do
    test "returns SourceLocation from module", %{vertex: vertex} do
      source_location = Vertex.SourceLocationProvider.source_location(vertex)

      assert %Clarity.SourceLocation{} = source_location
      assert :erl_anno.is_anno(source_location.anno)
      assert source_location.application == :ash
      assert source_location.module == Ash.Type.String

      file_path = Clarity.SourceLocation.file_path(source_location)
      if file_path, do: assert(String.ends_with?(file_path, "ash/lib/ash/type/string.ex"))
    end
  end

  describe inspect(&Clarity.Vertex.TooltipProvider.tooltip/1) do
    test "returns formatted overview", %{vertex: vertex} do
      overview = Vertex.TooltipProvider.tooltip(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "`Ash.Type.String`"
    end

    test "handles different Ash types" do
      vertex = %Type{type: Ash.Type.UUID}
      overview = Vertex.TooltipProvider.tooltip(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "`Ash.Type.UUID`"
    end

    test "handles boolean type" do
      vertex = %Type{type: Ash.Type.Boolean}
      overview = Vertex.TooltipProvider.tooltip(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "`Ash.Type.Boolean`"
    end

    test "handles atom types" do
      vertex = %Type{type: :string}
      overview = Vertex.TooltipProvider.tooltip(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "`:string`"
    end

    test "truncates long markdown content" do
      vertex = %Type{type: Ash.Type.String}
      overview = Vertex.TooltipProvider.tooltip(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "`Ash.Type.String`"
    end
  end
end
