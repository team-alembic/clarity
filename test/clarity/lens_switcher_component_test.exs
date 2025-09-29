defmodule Clarity.LensSwitcherComponentTest do
  use Clarity.Test.ConnCase, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias Clarity.Graph.Filter
  alias Clarity.LensSwitcherComponent
  alias Clarity.Perspective.Lens

  describe "LensSwitcherComponent" do
    test "renders aperture icon and current lens icon" do
      lens = %Lens{
        id: "debug",
        name: "Debug",
        description: "Debug lens",
        icon: fn ->
          assigns = %{}
          ~H"🐛"
        end,
        filter: Filter.custom(fn _vertex -> true end)
      }

      html =
        render_component(LensSwitcherComponent,
          id: "test-switcher",
          prefix: "/test",
          current_lens: lens
        )

      # Should show aperture icon
      assert html =~ ~s(<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 8 8")

      # Should show current lens icon
      assert html =~ "🐛"

      # Should have toggle button
      assert html =~ ~s(phx-click="toggle_dropdown")
    end

    test "has correct component structure" do
      lens = %Lens{
        id: "debug",
        name: "Debug",
        description: "Debug lens",
        icon: fn ->
          assigns = %{}
          ~H"🐛"
        end,
        filter: Filter.custom(fn _vertex -> true end)
      }

      html =
        render_component(LensSwitcherComponent,
          id: "test-switcher",
          prefix: "/test",
          current_lens: lens
        )

      # Should have relative container for dropdown positioning
      assert html =~ ~s(<div class="relative">)

      # Should have button with correct phx-target
      assert html =~ ~s(phx-target=)

      # Should have aria-label for accessibility
      assert html =~ ~s(aria-label="Switch lens perspective")
    end

    test "displays different lens icons correctly" do
      architect_lens = %Lens{
        id: "architect",
        name: "Architect",
        description: "Architect lens",
        icon: fn ->
          assigns = %{}
          ~H"🏗️"
        end,
        filter: Filter.custom(fn _vertex -> true end)
      }

      html =
        render_component(LensSwitcherComponent,
          id: "test-switcher",
          prefix: "/test",
          current_lens: architect_lens
        )

      # Should show current lens icon in button
      assert html =~ "🏗️"

      # Should not show other lens icons in button area
      refute html =~ "🐛"
      refute html =~ "🛡️"
    end

    test "component loads successfully with different prefixes" do
      lens = %Lens{
        id: "security",
        name: "Security",
        description: "Security lens",
        icon: fn ->
          assigns = %{}
          ~H"🛡️"
        end,
        filter: Filter.custom(fn _vertex -> true end)
      }

      html =
        render_component(LensSwitcherComponent,
          id: "test-switcher",
          prefix: "/custom",
          current_lens: lens
        )

      # Should render without errors and show current lens icon
      assert html =~ "🛡️"
      assert html =~ ~s(<svg class="w-5 h-5")
    end
  end
end
