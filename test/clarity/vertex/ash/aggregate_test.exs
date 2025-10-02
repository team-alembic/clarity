defmodule Clarity.Vertex.Ash.AggregateTest do
  use ExUnit.Case, async: true

  alias Ash.Resource.Info
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Aggregate
  alias Demo.Accounts.User
  alias Spark.Dsl.Entity

  setup do
    aggregate = User |> Info.aggregates() |> List.first()

    vertex = %Aggregate{aggregate: aggregate, resource: User}
    {:ok, vertex: vertex, aggregate: aggregate}
  end

  describe inspect(&Vertex.id/1) do
    test "returns correct unique identifier", %{vertex: vertex, aggregate: aggregate} do
      expected_name = aggregate.name |> to_string() |> String.replace("_", "-")
      assert Vertex.id(vertex) == "ash-aggregate:demo-accounts-user:#{expected_name}"
    end
  end

  describe inspect(&Vertex.type_label/1) do
    test "returns correct type label", %{vertex: vertex} do
      assert Vertex.type_label(vertex) == "Ash.Resource.Aggregate"
    end
  end

  describe inspect(&Vertex.name/1) do
    test "returns correct display name", %{vertex: vertex, aggregate: aggregate} do
      assert Vertex.name(vertex) == to_string(aggregate.name)
    end
  end

  describe inspect(&Clarity.Vertex.GraphGroupProvider.graph_group/1) do
    test "returns correct group", %{vertex: vertex} do
      assert Vertex.GraphGroupProvider.graph_group(vertex) == ["Demo.Accounts.User", "Ash.Resource.Aggregate"]
    end
  end

  describe inspect(&Clarity.Vertex.GraphShapeProvider.shape/1) do
    test "returns correct shape", %{vertex: vertex} do
      assert Vertex.GraphShapeProvider.shape(vertex) == "Mdiamond"
    end
  end

  describe inspect(&Clarity.Vertex.SourceLocationProvider.source_location/1) do
    test "returns SourceLocation from aggregate entity", %{vertex: vertex, aggregate: aggregate} do
      source_location = Vertex.SourceLocationProvider.source_location(vertex)

      assert %Clarity.SourceLocation{} = source_location
      assert source_location.anno == Entity.anno(aggregate)
      assert source_location.module == User
      assert source_location.application == :clarity
    end
  end

  describe inspect(&Clarity.Vertex.TooltipProvider.tooltip/1) do
    test "returns nil", %{vertex: vertex} do
      assert Vertex.TooltipProvider.tooltip(vertex) == nil
    end
  end
end
