defmodule Clarity.Content.Ash.RelationshipOverviewTest do
  use ExUnit.Case, async: true

  alias Ash.Resource.Info
  alias Clarity.Content.Ash.RelationshipOverview
  alias Clarity.Vertex.Ash.Relationship
  alias Clarity.Vertex.Root
  alias Demo.Accounts.User

  describe inspect(&RelationshipOverview.name/0) do
    test "returns relationship overview name" do
      assert RelationshipOverview.name() == "Relationship Overview"
    end
  end

  describe inspect(&RelationshipOverview.description/0) do
    test "returns relationship overview description" do
      assert RelationshipOverview.description() == "Overview of this Ash relationship"
    end
  end

  describe inspect(&RelationshipOverview.applies?/2) do
    test "returns true for Relationship vertices" do
      relationships = Info.relationships(User)

      if relationships != [] do
        [relationship | _] = relationships
        vertex = %Relationship{relationship: relationship, resource: User}
        lens = nil

        assert RelationshipOverview.applies?(vertex, lens)
      end
    end

    test "returns false for non-relationship vertices" do
      vertex = %Root{}
      lens = nil

      refute RelationshipOverview.applies?(vertex, lens)
    end
  end

  describe inspect(&RelationshipOverview.render_static/2) do
    test "returns markdown tuple with function" do
      relationships = Info.relationships(User)

      if relationships != [] do
        [relationship | _] = relationships
        vertex = %Relationship{relationship: relationship, resource: User}
        lens = nil

        assert {:markdown, markdown_fn} = RelationshipOverview.render_static(vertex, lens)
        assert is_function(markdown_fn, 1)
      end
    end

    test "generated markdown includes relationship header" do
      relationships = Info.relationships(User)

      if relationships != [] do
        [relationship | _] = relationships
        vertex = %Relationship{relationship: relationship, resource: User}
        {:markdown, markdown_fn} = RelationshipOverview.render_static(vertex, nil)

        props = %{theme: :light, zoom_subgraph: nil}
        markdown = IO.iodata_to_binary(markdown_fn.(props))

        assert markdown =~ "# #{relationship.name}"
        assert markdown =~ "**Type:**"
      end
    end

    test "generated markdown includes relationship information table" do
      relationships = Info.relationships(User)

      if relationships != [] do
        [relationship | _] = relationships
        vertex = %Relationship{relationship: relationship, resource: User}
        {:markdown, markdown_fn} = RelationshipOverview.render_static(vertex, nil)

        props = %{theme: :light, zoom_subgraph: nil}
        markdown = IO.iodata_to_binary(markdown_fn.(props))

        assert markdown =~ "## Relationship Information"
        assert markdown =~ "| Property | Value |"
        assert markdown =~ "Demo.Accounts.User"
      end
    end

    test "generated markdown includes characteristics section" do
      relationships = Info.relationships(User)

      if relationships != [] do
        [relationship | _] = relationships
        vertex = %Relationship{relationship: relationship, resource: User}
        {:markdown, markdown_fn} = RelationshipOverview.render_static(vertex, nil)

        props = %{theme: :light, zoom_subgraph: nil}
        markdown = IO.iodata_to_binary(markdown_fn.(props))

        assert markdown =~ "## Characteristics"
        assert markdown =~ "Public"
      end
    end

    test "generated markdown includes source and destination configuration" do
      relationships = Info.relationships(User)

      if relationships != [] do
        [relationship | _] = relationships
        vertex = %Relationship{relationship: relationship, resource: User}
        {:markdown, markdown_fn} = RelationshipOverview.render_static(vertex, nil)

        props = %{theme: :light, zoom_subgraph: nil}
        markdown = IO.iodata_to_binary(markdown_fn.(props))

        assert markdown =~ "## Source & Destination Configuration"
        assert markdown =~ "Source Attribute"
        assert markdown =~ "Destination Attribute"
      end
    end

    test "generated markdown includes vertex links" do
      relationships = Info.relationships(User)

      if relationships != [] do
        [relationship | _] = relationships
        vertex = %Relationship{relationship: relationship, resource: User}
        {:markdown, markdown_fn} = RelationshipOverview.render_static(vertex, nil)

        props = %{theme: :light, zoom_subgraph: nil}
        markdown = IO.iodata_to_binary(markdown_fn.(props))

        assert markdown =~ "vertex://ash-resource:demo-accounts-user"
      end
    end
  end
end
