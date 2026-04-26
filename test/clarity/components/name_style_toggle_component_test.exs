defmodule Clarity.NameStyleToggleComponentTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Clarity.NameStyleToggleComponent

  describe "rendering" do
    test "shows the click target as :short when qualified is active" do
      html =
        render_component(NameStyleToggleComponent, id: "test-toggle", name_style: :qualified)

      assert html =~ ~s|aria-pressed="false"|
      assert html =~ ~s|phx-value-style="short"|
      assert html =~ "Switch to short module names"
    end

    test "shows the click target as :qualified when short is active" do
      html =
        render_component(NameStyleToggleComponent, id: "test-toggle", name_style: :short)

      assert html =~ ~s|aria-pressed="true"|
      assert html =~ ~s|phx-value-style="qualified"|
      assert html =~ "Switch to fully-qualified module names"
    end
  end
end
