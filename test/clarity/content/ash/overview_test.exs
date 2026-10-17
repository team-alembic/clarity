defmodule Clarity.Content.Ash.OverviewTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Clarity.Components.OverviewComponents
  alias Clarity.Content.Ash.Overview
  alias Clarity.Perspective.Lensmaker.Architect
  alias Clarity.Vertex.Ash.Resource
  alias Demo.Accounts.User

  describe inspect(&Overview.resource_card/1) do
    test "breaks a long name after each dot, and keeps its badges" do
      html =
        (&Overview.resource_card/1)
        |> render_component(
          links:
            OverviewComponents.links(%{
              prefix: "/c",
              lens: Architect.make_lens(),
              vertex: %Resource{resource: User}
            }),
          resource: User,
          label: "UserNotificationPreferenceOverride.Version.History"
        )
        |> LazyHTML.from_fragment()

      [name] = html |> LazyHTML.query(".ov-resource-card a.ov-link") |> Enum.to_list()

      assert LazyHTML.text(name) =~ "UserNotificationPreferenceOverride.Version.History"

      assert name |> LazyHTML.query("span:not(.ov-icon)") |> LazyHTML.to_html() ==
               "<span>UserNotificationPreferenceOverride.<wbr/>Version.<wbr/>History</span>"

      assert html |> LazyHTML.query(".ov-flags .ov-flag") |> LazyHTML.text() =~ "multitenant"
    end
  end
end
