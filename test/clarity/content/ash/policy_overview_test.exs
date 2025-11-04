defmodule Clarity.Content.Ash.PolicyOverviewTest do
  use ExUnit.Case, async: true

  alias Clarity.Content.Ash.PolicyOverview
  alias Clarity.Vertex.Ash.Policy
  alias Clarity.Vertex.Root
  alias Demo.Accounts.User

  describe inspect(&PolicyOverview.name/0) do
    test "returns policy overview name" do
      assert PolicyOverview.name() == "Policy Overview"
    end
  end

  describe inspect(&PolicyOverview.description/0) do
    test "returns policy overview description" do
      assert PolicyOverview.description() == "Overview of this Ash policy"
    end
  end

  describe inspect(&PolicyOverview.applies?/2) do
    test "returns true for Policy vertices" do
      policy = %Ash.Policy.Policy{
        bypass?: false,
        description: "Test policy",
        policies: []
      }

      vertex = %Policy{policy: policy, resource: User}
      lens = nil

      assert PolicyOverview.applies?(vertex, lens)
    end

    test "returns false for non-policy vertices" do
      vertex = %Root{}
      lens = nil

      refute PolicyOverview.applies?(vertex, lens)
    end
  end

  describe inspect(&PolicyOverview.render_static/2) do
    test "returns markdown tuple with function" do
      policy = %Ash.Policy.Policy{
        bypass?: false,
        description: "Test policy",
        policies: []
      }

      vertex = %Policy{policy: policy, resource: User}
      lens = nil

      assert {:markdown, markdown_fn} = PolicyOverview.render_static(vertex, lens)
      assert is_function(markdown_fn, 1)
    end

    test "generated markdown includes policy header for standard policy" do
      policy = %Ash.Policy.Policy{
        bypass?: false,
        description: "Test policy",
        policies: []
      }

      vertex = %Policy{policy: policy, resource: User}
      {:markdown, markdown_fn} = PolicyOverview.render_static(vertex, nil)

      props = %{theme: :light, zoom_subgraph: nil}
      markdown = IO.iodata_to_binary(markdown_fn.(props))

      assert markdown =~ "# Standard Policy"
    end

    test "generated markdown includes policy header for bypass policy" do
      policy = %Ash.Policy.Policy{
        bypass?: true,
        description: "Test bypass policy",
        policies: []
      }

      vertex = %Policy{policy: policy, resource: User}
      {:markdown, markdown_fn} = PolicyOverview.render_static(vertex, nil)

      props = %{theme: :light, zoom_subgraph: nil}
      markdown = IO.iodata_to_binary(markdown_fn.(props))

      assert markdown =~ "# Bypass Policy"
    end

    test "generated markdown includes policy information table" do
      policy = %Ash.Policy.Policy{
        bypass?: false,
        description: "Test policy",
        policies: []
      }

      vertex = %Policy{policy: policy, resource: User}
      {:markdown, markdown_fn} = PolicyOverview.render_static(vertex, nil)

      props = %{theme: :light, zoom_subgraph: nil}
      markdown = IO.iodata_to_binary(markdown_fn.(props))

      assert markdown =~ "## Policy Information"
      assert markdown =~ "| Property | Value |"
      assert markdown =~ "Demo.Accounts.User"
    end

    test "generated markdown includes description when present" do
      policy = %Ash.Policy.Policy{
        bypass?: false,
        description: "Test policy description",
        policies: []
      }

      vertex = %Policy{policy: policy, resource: User}
      {:markdown, markdown_fn} = PolicyOverview.render_static(vertex, nil)

      props = %{theme: :light, zoom_subgraph: nil}
      markdown = IO.iodata_to_binary(markdown_fn.(props))

      assert markdown =~ "Test policy description"
    end

    test "generated markdown includes evaluation note" do
      policy = %Ash.Policy.Policy{
        bypass?: false,
        description: "Test policy",
        policies: []
      }

      vertex = %Policy{policy: policy, resource: User}
      {:markdown, markdown_fn} = PolicyOverview.render_static(vertex, nil)

      props = %{theme: :light, zoom_subgraph: nil}
      markdown = IO.iodata_to_binary(markdown_fn.(props))

      assert markdown =~ "## Policy Evaluation"
      assert markdown =~ "authorize_if"
      assert markdown =~ "forbid_if"
    end

    test "generated markdown includes vertex links" do
      policy = %Ash.Policy.Policy{
        bypass?: false,
        description: "Test policy",
        policies: []
      }

      vertex = %Policy{policy: policy, resource: User}
      {:markdown, markdown_fn} = PolicyOverview.render_static(vertex, nil)

      props = %{theme: :light, zoom_subgraph: nil}
      markdown = IO.iodata_to_binary(markdown_fn.(props))

      assert markdown =~ "vertex://ash-resource:demo-accounts-user"
    end
  end
end
