defmodule Clarity.Vertex.Ash.AggregateTest do
  use ExUnit.Case, async: true

  alias Ash.Resource.Info
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Aggregate
  alias Demo.Accounts.User
  alias Spark.Dsl.Entity

  describe "Clarity.Vertex protocol implementation for Ash.Aggregate" do
    setup do
      # Get a real aggregate from the Demo.Accounts.User resource
      aggregate = User |> Info.aggregates() |> List.first()

      vertex = %Aggregate{aggregate: aggregate, resource: User}
      {:ok, vertex: vertex, aggregate: aggregate}
    end

    test "unique_id/1 returns correct unique identifier", %{vertex: vertex, aggregate: aggregate} do
      assert Vertex.unique_id(vertex) == "aggregate:Demo.Accounts.User:#{aggregate.name}"
    end

    test "graph_id/1 returns correct graph identifier", %{vertex: vertex, aggregate: aggregate} do
      assert Vertex.graph_id(vertex) == ["Demo.Accounts.User", "_", "#{aggregate.name}"]
    end

    test "graph_group/1 returns correct group", %{vertex: vertex} do
      assert Vertex.graph_group(vertex) == ["Demo.Accounts.User", "Ash.Resource.Aggregate"]
    end

    test "type_label/1 returns correct type label", %{vertex: vertex} do
      assert Vertex.type_label(vertex) == "Ash.Resource.Aggregate"
    end

    test "render_name/1 returns correct display name", %{vertex: vertex, aggregate: aggregate} do
      assert Vertex.render_name(vertex) == to_string(aggregate.name)
    end

    test "dot_shape/1 returns correct shape", %{vertex: vertex} do
      assert Vertex.dot_shape(vertex) == "Mdiamond"
    end

    test "markdown_overview/1 returns empty list", %{vertex: vertex} do
      assert Vertex.markdown_overview(vertex) == []
    end

    test "source_anno/1 returns annotation from aggregate entity", %{vertex: vertex, aggregate: aggregate} do
      assert Vertex.source_anno(vertex) == Entity.anno(aggregate)
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
