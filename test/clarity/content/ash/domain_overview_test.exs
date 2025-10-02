defmodule Clarity.Content.Ash.DomainOverviewTest do
  use ExUnit.Case, async: true

  alias Clarity.Content.Ash.DomainOverview
  alias Clarity.Vertex.Ash.Domain
  alias Clarity.Vertex.Root
  alias Demo.Accounts.Domain, as: TestDomain

  describe inspect(&DomainOverview.name/0) do
    test "returns domain overview name" do
      assert DomainOverview.name() == "Domain Overview"
    end
  end

  describe inspect(&DomainOverview.description/0) do
    test "returns domain overview description" do
      assert DomainOverview.description() == "Overview of this Ash domain"
    end
  end

  describe inspect(&DomainOverview.applies?/2) do
    test "returns true for Domain vertices" do
      vertex = %Domain{domain: TestDomain}
      lens = nil

      assert DomainOverview.applies?(vertex, lens) == true
    end

    test "returns false for non-domain vertices" do
      vertex = %Root{}
      lens = nil

      assert DomainOverview.applies?(vertex, lens) == false
    end
  end

  describe inspect(&DomainOverview.render_static/2) do
    test "returns markdown tuple with function" do
      vertex = %Domain{domain: TestDomain}
      lens = nil

      assert {:markdown, markdown_fn} = DomainOverview.render_static(vertex, lens)
      assert is_function(markdown_fn, 1)
    end

    test "generated markdown includes domain information table" do
      vertex = %Domain{domain: TestDomain}
      {:markdown, markdown_fn} = DomainOverview.render_static(vertex, nil)

      props = %{theme: :light, zoom_subgraph: nil}
      markdown = IO.iodata_to_binary(markdown_fn.(props))

      assert markdown =~ "## Domain Information"
      assert markdown =~ "| Property | Value |"
      assert markdown =~ "Demo.Accounts.Domain"
    end

    test "generated markdown includes resources table" do
      vertex = %Domain{domain: TestDomain}
      {:markdown, markdown_fn} = DomainOverview.render_static(vertex, nil)

      props = %{theme: :light, zoom_subgraph: nil}
      markdown = IO.iodata_to_binary(markdown_fn.(props))

      assert markdown =~ "## Resources"
      assert markdown =~ "| Resource | Description |"
      assert markdown =~ "Demo.Accounts.User"
    end

    test "generated markdown extracts first paragraph from moduledoc" do
      vertex = %Domain{domain: TestDomain}
      {:markdown, markdown_fn} = DomainOverview.render_static(vertex, nil)

      props = %{theme: :light, zoom_subgraph: nil}
      markdown = IO.iodata_to_binary(markdown_fn.(props))

      assert markdown =~ "Accounts domain"
      refute markdown =~ "second paragraph"
    end

    test "generated markdown includes resource descriptions" do
      vertex = %Domain{domain: TestDomain}
      {:markdown, markdown_fn} = DomainOverview.render_static(vertex, nil)

      props = %{theme: :light, zoom_subgraph: nil}
      markdown = IO.iodata_to_binary(markdown_fn.(props))

      assert markdown =~ "Demo.Accounts.User"
    end

    test "generated markdown includes vertex links" do
      vertex = %Domain{domain: TestDomain}
      {:markdown, markdown_fn} = DomainOverview.render_static(vertex, nil)

      props = %{theme: :light, zoom_subgraph: nil}
      markdown = IO.iodata_to_binary(markdown_fn.(props))

      assert markdown =~ "vertex://ash-domain:demo-accounts-domain"
      assert markdown =~ "vertex://ash-resource:demo-accounts-user"
    end
  end
end
