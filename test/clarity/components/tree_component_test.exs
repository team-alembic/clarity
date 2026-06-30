defmodule Clarity.TreeComponentTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Clarity.TreeComponent

  describe "status_badge/1" do
    test "renders nothing without an entry" do
      html = render_component(&TreeComponent.status_badge/1, entry: nil)

      refute html =~ "svg"
    end

    test "renders an error pill without a count for a single issue" do
      html = render_component(&TreeComponent.status_badge/1, entry: %{severity: :error, count: 1})

      assert html =~ "rounded-full"
      assert html =~ "bg-red-100"
      # the count span (tabular-nums) is only shown for more than one issue
      refute html =~ "tabular-nums"
    end

    test "shows the count when more than one issue" do
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
end
