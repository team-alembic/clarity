defmodule Clarity.Vertex.Ash.DomainTest do
  use ExUnit.Case, async: true

  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Domain
  alias Demo.Accounts.Domain, as: TestDomain

  describe "Clarity.Vertex protocol implementation for Ash.Domain" do
    setup do
      vertex = %Domain{domain: TestDomain}
      {:ok, vertex: vertex}
    end

    test "unique_id/1 returns correct unique identifier", %{vertex: vertex} do
      assert Vertex.unique_id(vertex) == "domain:Demo.Accounts.Domain"
    end

    test "graph_id/1 returns correct graph identifier", %{vertex: vertex} do
      assert Vertex.graph_id(vertex) == "Demo.Accounts.Domain"
    end

    test "graph_group/1 returns empty list", %{vertex: vertex} do
      assert Vertex.graph_group(vertex) == []
    end

    test "type_label/1 returns correct type label", %{vertex: vertex} do
      assert Vertex.type_label(vertex) == "Ash.Domain"
    end

    test "render_name/1 returns correct display name", %{vertex: vertex} do
      assert Vertex.render_name(vertex) == "Demo.Accounts.Domain"
    end

    test "dot_shape/1 returns correct shape", %{vertex: vertex} do
      assert Vertex.dot_shape(vertex) == "folder"
    end

    test "markdown_overview/1 returns formatted overview", %{vertex: vertex} do
      overview = Vertex.markdown_overview(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "`Demo.Accounts.Domain`"
    end

    test "source_location/1 returns SourceLocation from module", %{vertex: vertex} do
      source_location = Vertex.source_location(vertex)

      assert %Clarity.SourceLocation{} = source_location
      assert :erl_anno.is_anno(source_location.anno)
      assert source_location.application == :clarity
      assert source_location.module == TestDomain

      file_path = Clarity.SourceLocation.file_path(source_location)
      if file_path, do: assert(String.ends_with?(file_path, "dev/demo/accounts/domain.ex"))
    end
  end

  describe "Domain struct" do
    test "enforces required keys" do
      assert_raise ArgumentError, fn ->
        struct!(Domain, %{})
      end
    end

    test "creates struct with required domain field" do
      vertex = %Domain{domain: TestDomain}

      assert vertex.domain == TestDomain
    end
  end
end
