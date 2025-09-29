defmodule Clarity.Vertex.Ash.RelationshipTest do
  use ExUnit.Case, async: true

  alias Ash.Resource.Info
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Relationship
  alias Demo.Accounts.User
  alias Spark.Dsl.Entity

  describe "Clarity.Vertex protocol implementation for Ash.Relationship" do
    setup do
      # Get a real relationship from the Demo.Accounts.User resource
      relationship = User |> Info.relationships() |> List.first()

      vertex = %Relationship{relationship: relationship, resource: User}
      {:ok, vertex: vertex, relationship: relationship}
    end

    test "unique_id/1 returns correct unique identifier", %{vertex: vertex, relationship: relationship} do
      assert Vertex.unique_id(vertex) == "relationship:Demo.Accounts.User:#{relationship.name}"
    end

    test "graph_id/1 returns correct graph identifier", %{vertex: vertex, relationship: relationship} do
      assert Vertex.graph_id(vertex) == ["Demo.Accounts.User", "_", "#{relationship.name}"]
    end

    test "graph_group/1 returns correct group", %{vertex: vertex} do
      assert Vertex.graph_group(vertex) == ["Demo.Accounts.User", "Ash.Resource.Relationships"]
    end

    test "type_label/1 returns correct type label", %{vertex: vertex, relationship: relationship} do
      assert Vertex.type_label(vertex) == relationship.__struct__ |> Module.split() |> Enum.join(".")
    end

    test "render_name/1 returns correct display name", %{vertex: vertex, relationship: relationship} do
      assert Vertex.render_name(vertex) == to_string(relationship.name)
    end

    test "dot_shape/1 returns correct shape", %{vertex: vertex} do
      assert Vertex.dot_shape(vertex) == "rarrow"
    end

    test "markdown_overview/1 returns empty list", %{vertex: vertex} do
      assert Vertex.markdown_overview(vertex) == []
    end

    test "source_location/1 returns SourceLocation from relationship entity", %{
      vertex: vertex,
      relationship: relationship
    } do
      source_location = Vertex.source_location(vertex)

      assert %Clarity.SourceLocation{} = source_location
      assert source_location.anno == Entity.anno(relationship)
      assert source_location.module == User
      assert source_location.application == :clarity
    end
  end

  describe "Relationship struct" do
    test "enforces required keys" do
      assert_raise ArgumentError, fn ->
        struct!(Relationship, %{})
      end
    end

    test "creates struct with required fields" do
      relationship = %Ash.Resource.Relationships.HasMany{
        name: :posts,
        destination: Demo.Blog.Post
      }

      vertex = %Relationship{relationship: relationship, resource: User}

      assert vertex.relationship == relationship
      assert vertex.resource == User
    end
  end
end
