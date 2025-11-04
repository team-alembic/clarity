defmodule Clarity.Content.Ash.AttributeOverviewTest do
  use ExUnit.Case, async: true

  alias Ash.Resource.Info
  alias Clarity.Content.Ash.AttributeOverview
  alias Clarity.Vertex.Ash.Attribute
  alias Clarity.Vertex.Root
  alias Demo.Accounts.User

  describe inspect(&AttributeOverview.name/0) do
    test "returns attribute overview name" do
      assert AttributeOverview.name() == "Attribute Overview"
    end
  end

  describe inspect(&AttributeOverview.description/0) do
    test "returns attribute overview description" do
      assert AttributeOverview.description() == "Overview of this Ash attribute"
    end
  end

  describe inspect(&AttributeOverview.applies?/2) do
    test "returns true for Attribute vertices" do
      [attribute | _] = Info.attributes(User)
      vertex = %Attribute{attribute: attribute, resource: User}
      lens = nil

      assert AttributeOverview.applies?(vertex, lens)
    end

    test "returns false for non-attribute vertices" do
      vertex = %Root{}
      lens = nil

      refute AttributeOverview.applies?(vertex, lens)
    end
  end

  describe inspect(&AttributeOverview.render_static/2) do
    test "returns markdown tuple with function" do
      [attribute | _] = Info.attributes(User)
      vertex = %Attribute{attribute: attribute, resource: User}
      lens = nil

      assert {:markdown, markdown_fn} = AttributeOverview.render_static(vertex, lens)
      assert is_function(markdown_fn, 1)
    end

    test "generated markdown includes attribute header" do
      [attribute | _] = Info.attributes(User)
      vertex = %Attribute{attribute: attribute, resource: User}
      {:markdown, markdown_fn} = AttributeOverview.render_static(vertex, nil)

      props = %{theme: :light, zoom_subgraph: nil}
      markdown = IO.iodata_to_binary(markdown_fn.(props))

      assert markdown =~ "# #{attribute.name}"
      assert markdown =~ "**Type:**"
    end

    test "generated markdown includes attribute information table" do
      [attribute | _] = Info.attributes(User)
      vertex = %Attribute{attribute: attribute, resource: User}
      {:markdown, markdown_fn} = AttributeOverview.render_static(vertex, nil)

      props = %{theme: :light, zoom_subgraph: nil}
      markdown = IO.iodata_to_binary(markdown_fn.(props))

      assert markdown =~ "## Attribute Information"
      assert markdown =~ "| Property | Value |"
      assert markdown =~ "Demo.Accounts.User"
    end

    test "generated markdown includes characteristics section" do
      [attribute | _] = Info.attributes(User)
      vertex = %Attribute{attribute: attribute, resource: User}
      {:markdown, markdown_fn} = AttributeOverview.render_static(vertex, nil)

      props = %{theme: :light, zoom_subgraph: nil}
      markdown = IO.iodata_to_binary(markdown_fn.(props))

      assert markdown =~ "## Characteristics"
      assert markdown =~ "Primary Key"
      assert markdown =~ "Allow Nil"
      assert markdown =~ "Public"
      assert markdown =~ "Writable"
    end

    test "generated markdown includes constraints section when attribute has constraints" do
      attributes = Info.attributes(User)

      attribute_with_constraints =
        Enum.find(attributes, fn a ->
          not Enum.empty?(a.constraints || [])
        end)

      if attribute_with_constraints do
        vertex = %Attribute{attribute: attribute_with_constraints, resource: User}
        {:markdown, markdown_fn} = AttributeOverview.render_static(vertex, nil)

        props = %{theme: :light, zoom_subgraph: nil}
        markdown = IO.iodata_to_binary(markdown_fn.(props))

        assert markdown =~ "## Constraints"
      end
    end

    test "generated markdown includes vertex links" do
      [attribute | _] = Info.attributes(User)
      vertex = %Attribute{attribute: attribute, resource: User}
      {:markdown, markdown_fn} = AttributeOverview.render_static(vertex, nil)

      props = %{theme: :light, zoom_subgraph: nil}
      markdown = IO.iodata_to_binary(markdown_fn.(props))

      assert markdown =~ "vertex://ash-resource:demo-accounts-user"
    end
  end
end
