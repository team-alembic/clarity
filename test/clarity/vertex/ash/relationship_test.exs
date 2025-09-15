defmodule Clarity.Vertex.Ash.RelationshipTest do
  use ExUnit.Case, async: true

  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Relationship
  alias Demo.Accounts.User

  describe "Clarity.Vertex protocol implementation for Ash.Relationship" do
    setup do
      # Create a mock relationship structure (like belongs_to, has_many, etc.)
      relationship = %Ash.Resource.Relationships.BelongsTo{
        name: :user,
        destination: User,
        source_attribute: :user_id,
        destination_attribute: :id
      }

      vertex = %Relationship{relationship: relationship, resource: Demo.Accounts.Profile}
      {:ok, vertex: vertex}
    end

    test "unique_id/1 returns correct unique identifier", %{vertex: vertex} do
      assert Vertex.unique_id(vertex) == "relationship:Demo.Accounts.Profile:user"
    end

    test "graph_id/1 returns correct graph identifier", %{vertex: vertex} do
      assert Vertex.graph_id(vertex) == ["Demo.Accounts.Profile", "_", "user"]
    end

    test "graph_group/1 returns correct group", %{vertex: vertex} do
      assert Vertex.graph_group(vertex) == ["Demo.Accounts.Profile", "Ash.Resource.Relationships"]
    end

    test "type_label/1 returns correct type label", %{vertex: vertex} do
      assert Vertex.type_label(vertex) == "Ash.Resource.Relationships.BelongsTo"
    end

    test "render_name/1 returns correct display name", %{vertex: vertex} do
      assert Vertex.render_name(vertex) == "user"
    end

    test "dot_shape/1 returns correct shape", %{vertex: vertex} do
      assert Vertex.dot_shape(vertex) == "rarrow"
    end

    test "markdown_overview/1 returns empty list", %{vertex: vertex} do
      assert Vertex.markdown_overview(vertex) == []
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
