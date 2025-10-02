defmodule Clarity.Content.Ash.ResourceOverviewTest do
  use ExUnit.Case, async: true

  alias Clarity.Content.Ash.ResourceOverview
  alias Clarity.Vertex.Ash.Resource
  alias Clarity.Vertex.Root
  alias Demo.Accounts.User

  describe inspect(&ResourceOverview.name/0) do
    test "returns resource overview name" do
      assert ResourceOverview.name() == "Resource Overview"
    end
  end

  describe inspect(&ResourceOverview.description/0) do
    test "returns resource overview description" do
      assert ResourceOverview.description() == "Overview of this Ash resource"
    end
  end

  describe inspect(&ResourceOverview.applies?/2) do
    test "returns true for Resource vertices" do
      vertex = %Resource{resource: User}
      lens = nil

      assert ResourceOverview.applies?(vertex, lens) == true
    end

    test "returns false for non-resource vertices" do
      vertex = %Root{}
      lens = nil

      assert ResourceOverview.applies?(vertex, lens) == false
    end
  end

  describe inspect(&ResourceOverview.render_static/2) do
    test "returns markdown tuple with function" do
      vertex = %Resource{resource: User}
      lens = nil

      assert {:markdown, markdown_fn} = ResourceOverview.render_static(vertex, lens)
      assert is_function(markdown_fn, 1)
    end

    test "generated markdown includes resource information table" do
      vertex = %Resource{resource: User}
      {:markdown, markdown_fn} = ResourceOverview.render_static(vertex, nil)

      props = %{theme: :light, zoom_subgraph: nil}
      markdown = IO.iodata_to_binary(markdown_fn.(props))

      assert markdown =~ "## Resource Information"
      assert markdown =~ "| Property | Value |"
      assert markdown =~ "Demo.Accounts.User"
      assert markdown =~ "Demo.Accounts.Domain"
    end

    test "generated markdown includes attributes section" do
      vertex = %Resource{resource: User}
      {:markdown, markdown_fn} = ResourceOverview.render_static(vertex, nil)

      props = %{theme: :light, zoom_subgraph: nil}
      markdown = IO.iodata_to_binary(markdown_fn.(props))

      assert markdown =~ "## Attributes"
      assert markdown =~ "| Name | Type |"
    end

    test "generated markdown includes relationships section" do
      vertex = %Resource{resource: User}
      {:markdown, markdown_fn} = ResourceOverview.render_static(vertex, nil)

      props = %{theme: :light, zoom_subgraph: nil}
      markdown = IO.iodata_to_binary(markdown_fn.(props))

      assert markdown =~ "## Relationships"
    end

    test "generated markdown includes actions section" do
      vertex = %Resource{resource: User}
      {:markdown, markdown_fn} = ResourceOverview.render_static(vertex, nil)

      props = %{theme: :light, zoom_subgraph: nil}
      markdown = IO.iodata_to_binary(markdown_fn.(props))

      assert markdown =~ "## Actions"
      assert markdown =~ "| Name | Description |"
    end

    test "generated markdown includes aggregates section" do
      vertex = %Resource{resource: User}
      {:markdown, markdown_fn} = ResourceOverview.render_static(vertex, nil)

      props = %{theme: :light, zoom_subgraph: nil}
      markdown = IO.iodata_to_binary(markdown_fn.(props))

      assert markdown =~ "## Aggregates"
    end

    test "generated markdown includes calculations section" do
      vertex = %Resource{resource: User}
      {:markdown, markdown_fn} = ResourceOverview.render_static(vertex, nil)

      props = %{theme: :light, zoom_subgraph: nil}
      markdown = IO.iodata_to_binary(markdown_fn.(props))

      assert markdown =~ "## Calculations"
    end

    test "generated markdown includes vertex links" do
      vertex = %Resource{resource: User}
      {:markdown, markdown_fn} = ResourceOverview.render_static(vertex, nil)

      props = %{theme: :light, zoom_subgraph: nil}
      markdown = IO.iodata_to_binary(markdown_fn.(props))

      assert markdown =~ "vertex://ash-resource:demo-accounts-user"
      assert markdown =~ "vertex://ash-domain:demo-accounts-domain"
    end

    test "generated markdown handles data layer information" do
      vertex = %Resource{resource: User}
      {:markdown, markdown_fn} = ResourceOverview.render_static(vertex, nil)

      props = %{theme: :light, zoom_subgraph: nil}
      markdown = IO.iodata_to_binary(markdown_fn.(props))

      assert markdown =~ "Data Layer"
    end
  end
end
