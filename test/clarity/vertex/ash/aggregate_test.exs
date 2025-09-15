defmodule Clarity.Vertex.Ash.AggregateTest do
  use ExUnit.Case, async: true

  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Aggregate
  alias Demo.Accounts.User

  describe "Clarity.Vertex protocol implementation for Ash.Aggregate" do
    setup do
      # Create a mock aggregate structure
      aggregate = %{
        name: :total_count,
        type: :count,
        resource: User
      }

      vertex = %Aggregate{aggregate: aggregate, resource: User}
      {:ok, vertex: vertex}
    end

    test "unique_id/1 returns correct unique identifier", %{vertex: vertex} do
      assert Vertex.unique_id(vertex) == "aggregate:Demo.Accounts.User:total_count"
    end

    test "graph_id/1 returns correct graph identifier", %{vertex: vertex} do
      assert Vertex.graph_id(vertex) == ["Demo.Accounts.User", "_", "total_count"]
    end

    test "graph_group/1 returns correct group", %{vertex: vertex} do
      assert Vertex.graph_group(vertex) == ["Demo.Accounts.User", "Ash.Resource.Aggregate"]
    end

    test "type_label/1 returns correct type label", %{vertex: vertex} do
      assert Vertex.type_label(vertex) == "Ash.Resource.Aggregate"
    end

    test "render_name/1 returns correct display name", %{vertex: vertex} do
      assert Vertex.render_name(vertex) == "total_count"
    end

    test "dot_shape/1 returns correct shape", %{vertex: vertex} do
      assert Vertex.dot_shape(vertex) == "Mdiamond"
    end

    test "markdown_overview/1 returns empty list", %{vertex: vertex} do
      assert Vertex.markdown_overview(vertex) == []
    end
  end

  describe "Aggregate struct" do
    test "enforces required keys" do
      assert_raise ArgumentError, fn ->
        struct!(Aggregate, %{})
      end
    end

    test "creates struct with required fields" do
      aggregate = %{name: :count, type: :count}
      vertex = %Aggregate{aggregate: aggregate, resource: User}

      assert vertex.aggregate == aggregate
      assert vertex.resource == User
    end
  end
end
