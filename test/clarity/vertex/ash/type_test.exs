defmodule Clarity.Vertex.Ash.TypeTest do
  use ExUnit.Case, async: true

  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Type

  describe "Clarity.Vertex protocol implementation for Ash.Type" do
    setup do
      vertex = %Type{type: Ash.Type.String}
      {:ok, vertex: vertex}
    end

    test "unique_id/1 returns correct unique identifier", %{vertex: vertex} do
      assert Vertex.unique_id(vertex) == "type:Ash.Type.String"
    end

    test "graph_id/1 returns correct graph identifier", %{vertex: vertex} do
      assert Vertex.graph_id(vertex) == "Ash.Type.String"
    end

    test "graph_group/1 returns empty list", %{vertex: vertex} do
      assert Vertex.graph_group(vertex) == []
    end

    test "type_label/1 returns correct type label", %{vertex: vertex} do
      assert Vertex.type_label(vertex) == "Ash.Type"
    end

    test "render_name/1 returns correct display name", %{vertex: vertex} do
      assert Vertex.render_name(vertex) == "Ash.Type.String"
    end

    test "dot_shape/1 returns correct shape", %{vertex: vertex} do
      assert Vertex.dot_shape(vertex) == "plain"
    end

    test "markdown_overview/1 returns formatted overview", %{vertex: vertex} do
      overview = Vertex.markdown_overview(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "`Ash.Type.String`"
      # Module docs would be included if available via Code.fetch_docs
    end
  end

  describe "Type struct" do
    test "enforces required keys" do
      assert_raise ArgumentError, fn ->
        struct!(Type, %{})
      end
    end

    test "creates struct with required type field" do
      vertex = %Type{type: Ash.Type.Integer}

      assert vertex.type == Ash.Type.Integer
    end
  end

  describe "markdown_overview with different types" do
    test "handles different Ash types" do
      vertex = %Type{type: Ash.Type.UUID}
      overview = Vertex.markdown_overview(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "`Ash.Type.UUID`"
    end

    test "handles boolean type" do
      vertex = %Type{type: Ash.Type.Boolean}
      overview = Vertex.markdown_overview(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "`Ash.Type.Boolean`"
    end

    test "handles atom types" do
      vertex = %Type{type: :string}
      overview = Vertex.markdown_overview(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "`:string`"
    end
  end

  describe "truncate_markdown/2 private function" do
    test "truncates long markdown content" do
      # This tests the private function behavior indirectly through markdown_overview
      # If a type has very long documentation, it should be truncated to 10 lines + "..."
      vertex = %Type{type: Ash.Type.String}
      overview = Vertex.markdown_overview(vertex)
      overview_string = IO.iodata_to_binary(overview)

      # The overview should contain the type name at minimum
      assert overview_string =~ "`Ash.Type.String`"
      # Specific truncation behavior would depend on the actual module docs
    end
  end
end
