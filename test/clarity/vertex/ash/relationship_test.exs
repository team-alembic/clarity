defmodule Clarity.Vertex.Ash.RelationshipTest do
  use ExUnit.Case, async: true

  alias Ash.Resource.Info
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Relationship
  alias Demo.Accounts.User
  alias Spark.Dsl.Entity

  setup do
    relationship = User |> Info.relationships() |> List.first()

    vertex = %Relationship{relationship: relationship, resource: User}
    {:ok, vertex: vertex, relationship: relationship}
  end

  describe inspect(&Vertex.id/1) do
    test "returns correct unique identifier", %{vertex: vertex, relationship: relationship} do
      assert Vertex.id(vertex) == "ash-relationship:demo-accounts-user:#{relationship.name}"
    end
  end

  describe inspect(&Vertex.type_label/1) do
    test "returns correct type label", %{vertex: vertex, relationship: relationship} do
      assert Vertex.type_label(vertex) == relationship.__struct__ |> Module.split() |> Enum.join(".")
    end
  end

  describe inspect(&Vertex.name/1) do
    test "returns correct display name", %{vertex: vertex, relationship: relationship} do
      assert Vertex.name(vertex) == to_string(relationship.name)
    end
  end

  describe inspect(&Clarity.Vertex.GraphGroupProvider.graph_group/1) do
    test "returns correct group", %{vertex: vertex} do
      assert Vertex.GraphGroupProvider.graph_group(vertex) == ["Demo.Accounts.User", "Ash.Resource.Relationships"]
    end
  end

  describe inspect(&Clarity.Vertex.GraphShapeProvider.shape/1) do
    test "returns correct shape", %{vertex: vertex} do
      assert Vertex.GraphShapeProvider.shape(vertex) == "rarrow"
    end
  end

  describe inspect(&Clarity.Vertex.SourceLocationProvider.source_location/1) do
    test "returns SourceLocation from relationship entity", %{
      vertex: vertex,
      relationship: relationship
    } do
      source_location = Vertex.SourceLocationProvider.source_location(vertex)

      assert %Clarity.SourceLocation{} = source_location
      assert source_location.anno == Entity.anno(relationship)
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
