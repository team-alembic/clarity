defmodule Clarity.Content.Ash.ActionOverviewTest do
  use ExUnit.Case, async: true

  alias Ash.Resource.Info
  alias Clarity.Content.Ash.ActionOverview
  alias Clarity.Vertex.Ash.Action
  alias Clarity.Vertex.Root
  alias Demo.Accounts.User

  describe inspect(&ActionOverview.name/0) do
    test "returns action overview name" do
      assert ActionOverview.name() == "Action Overview"
    end
  end

  describe inspect(&ActionOverview.description/0) do
    test "returns action overview description" do
      assert ActionOverview.description() == "Overview of this Ash action"
    end
  end

  describe inspect(&ActionOverview.applies?/2) do
    test "returns true for Action vertices" do
      [action | _] = Info.actions(User)
      vertex = %Action{action: action, resource: User}
      lens = nil

      assert ActionOverview.applies?(vertex, lens)
    end

    test "returns false for non-action vertices" do
      vertex = %Root{}
      lens = nil

      refute ActionOverview.applies?(vertex, lens)
    end
  end

  describe inspect(&ActionOverview.render_static/2) do
    test "returns markdown tuple with function" do
      [action | _] = Info.actions(User)
      vertex = %Action{action: action, resource: User}
      lens = nil

      assert {:markdown, markdown_fn} = ActionOverview.render_static(vertex, lens)
      assert is_function(markdown_fn, 1)
    end

    test "generated markdown includes action header" do
      [action | _] = Info.actions(User)
      vertex = %Action{action: action, resource: User}
      {:markdown, markdown_fn} = ActionOverview.render_static(vertex, nil)

      props = %{theme: :light, zoom_subgraph: nil}
      markdown = IO.iodata_to_binary(markdown_fn.(props))

      assert markdown =~ "# #{action.name}"
      assert markdown =~ "**Type:**"
    end

    test "generated markdown includes action information table" do
      [action | _] = Info.actions(User)
      vertex = %Action{action: action, resource: User}
      {:markdown, markdown_fn} = ActionOverview.render_static(vertex, nil)

      props = %{theme: :light, zoom_subgraph: nil}
      markdown = IO.iodata_to_binary(markdown_fn.(props))

      assert markdown =~ "## Action Information"
      assert markdown =~ "| Property | Value |"
      assert markdown =~ "Demo.Accounts.User"
    end

    test "generated markdown includes configuration section" do
      [action | _] = Info.actions(User)
      vertex = %Action{action: action, resource: User}
      {:markdown, markdown_fn} = ActionOverview.render_static(vertex, nil)

      props = %{theme: :light, zoom_subgraph: nil}
      markdown = IO.iodata_to_binary(markdown_fn.(props))

      assert markdown =~ "## Configuration"
      assert markdown =~ "Transaction"
    end

    test "generated markdown includes arguments section when action has arguments" do
      actions = Info.actions(User)
      action_with_args = Enum.find(actions, fn a -> length(a.arguments) > 0 end)

      if action_with_args do
        vertex = %Action{action: action_with_args, resource: User}
        {:markdown, markdown_fn} = ActionOverview.render_static(vertex, nil)

        props = %{theme: :light, zoom_subgraph: nil}
        markdown = IO.iodata_to_binary(markdown_fn.(props))

        assert markdown =~ "## Arguments"
      end
    end

    test "generated markdown includes vertex links" do
      [action | _] = Info.actions(User)
      vertex = %Action{action: action, resource: User}
      {:markdown, markdown_fn} = ActionOverview.render_static(vertex, nil)

      props = %{theme: :light, zoom_subgraph: nil}
      markdown = IO.iodata_to_binary(markdown_fn.(props))

      assert markdown =~ "vertex://ash-resource:demo-accounts-user"
    end
  end
end
