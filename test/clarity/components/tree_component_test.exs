defmodule Clarity.TreeComponentTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Clarity.TreeComponent

  describe "status_badge/1" do
    test "renders nothing without an entry" do
      html = render_component(&TreeComponent.status_badge/1, entry: nil)

      refute html =~ "svg"
    end

    test "renders a pill with no count for a flagged leaf (no nested issues)" do
      html = render_component(&TreeComponent.status_badge/1, entry: %{severity: :error, count: 0})

      assert html =~ "rounded-full"
      assert html =~ "bg-red-100"
      # the count span (tabular-nums) is only shown when there are nested issues
      refute html =~ "tabular-nums"
    end

    test "shows the count of nested issues" do
      html = render_component(&TreeComponent.status_badge/1, entry: %{severity: :error, count: 3})

      assert html =~ "bg-red-100"
      assert html =~ "tabular-nums"
      assert html =~ "3"
    end

    test "renders warning and info severities" do
      warning =
        render_component(&TreeComponent.status_badge/1, entry: %{severity: :warning, count: 1})

      assert warning =~ "bg-yellow-100"

      info = render_component(&TreeComponent.status_badge/1, entry: %{severity: :info, count: 1})

      assert info =~ "bg-blue-100"
    end
  end

  describe "status_badge/1 hint" do
    test "describes nested issues in a hover hint and an accessible name" do
      html = render_component(&TreeComponent.status_badge/1, entry: %{severity: :error, count: 3})

      badge = html |> LazyHTML.from_fragment() |> LazyHTML.query("[data-tooltip-text='3 nested issues']")

      assert LazyHTML.attribute(badge, "aria-label") == ["3 nested issues"]
    end
  end
end
