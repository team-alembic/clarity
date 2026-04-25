defmodule Clarity.D2LayoutSwitcherComponentTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Clarity.D2LayoutSwitcherComponent

  describe inspect(&D2LayoutSwitcherComponent.layouts/0) do
    test "exposes dagre and elk" do
      ids = Enum.map(D2LayoutSwitcherComponent.layouts(), & &1.id)
      assert "dagre" in ids
      assert "elk" in ids
    end
  end

  describe inspect(&D2LayoutSwitcherComponent.lookup/1) do
    test "returns the matching entry" do
      assert %{id: "elk"} = D2LayoutSwitcherComponent.lookup("elk")
    end

    test "falls back to the first layout for unknown ids" do
      assert %{id: "dagre"} = D2LayoutSwitcherComponent.lookup("unknown")
    end
  end

  describe "live_component rendering" do
    test "renders the trigger button with the active layout id" do
      html =
        render_component(D2LayoutSwitcherComponent,
          id: "test-d2-switcher",
          d2_layout: "dagre"
        )

      assert html =~ ~s|aria-label="Switch D2 layout engine"|
      assert html =~ ">dagre<"
    end
  end
end
