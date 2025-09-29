defmodule Clarity.Vertex.Ash.ResourceTest do
  use ExUnit.Case, async: true

  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Resource
  alias Demo.Accounts.User

  describe "Clarity.Vertex protocol implementation for Ash.Resource" do
    setup do
      vertex = %Resource{resource: User}
      {:ok, vertex: vertex}
    end

    test "unique_id/1 returns correct unique identifier", %{vertex: vertex} do
      assert Vertex.unique_id(vertex) == "resource:Demo.Accounts.User"
    end

    test "graph_id/1 returns correct graph identifier", %{vertex: vertex} do
      assert Vertex.graph_id(vertex) == "Demo.Accounts.User"
    end

    test "graph_group/1 returns resource name in array", %{vertex: vertex} do
      assert Vertex.graph_group(vertex) == ["Demo.Accounts.User"]
    end

    test "type_label/1 returns correct type label", %{vertex: vertex} do
      assert Vertex.type_label(vertex) == "Ash.Resource"
    end

    test "render_name/1 returns correct display name", %{vertex: vertex} do
      assert Vertex.render_name(vertex) == "Demo.Accounts.User"
    end

    test "dot_shape/1 returns correct shape", %{vertex: vertex} do
      assert Vertex.dot_shape(vertex) == "component"
    end

    test "markdown_overview/1 returns formatted overview", %{vertex: vertex} do
      overview = Vertex.markdown_overview(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "`Demo.Accounts.User`"
      assert overview_string =~ "Domain: `Demo.Accounts.Domain`"
    end

    test "source_location/1 returns SourceLocation from module", %{vertex: vertex} do
      source_location = Vertex.source_location(vertex)

      assert %Clarity.SourceLocation{} = source_location
      assert :erl_anno.is_anno(source_location.anno)
      assert source_location.application == :clarity
      assert source_location.module == User

      file_path = Clarity.SourceLocation.file_path(source_location)
      if file_path, do: assert(String.ends_with?(file_path, "dev/demo/accounts/user.ex"))
    end
  end

  describe "Resource struct" do
    test "enforces required keys" do
      assert_raise ArgumentError, fn ->
        struct!(Resource, %{})
      end
    end

    test "creates struct with required resource field" do
      vertex = %Resource{resource: User}

      assert vertex.resource == User
    end
  end
end
