defmodule Clarity.Content.Ash.OverviewTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Clarity.Components.OverviewComponents
  alias Clarity.Content.Ash.Overview
  alias Clarity.Perspective.Lensmaker.Architect
  alias Clarity.Vertex.Ash.Resource
  alias Demo.Accounts.User

  describe inspect(&Overview.resource_card/1) do
    test "breaks a long name after each dot" do
      html = render_card("UserNotificationPreferenceOverride.Version.History")

      [name] = html |> LazyHTML.query(".ov-resource-card a.ov-link") |> Enum.to_list()

      assert LazyHTML.text(name) =~ "UserNotificationPreferenceOverride.Version.History"

      assert name |> LazyHTML.query("span:not(.ov-icon)") |> LazyHTML.to_html() ==
               "<span>UserNotificationPreferenceOverride.<wbr/>Version.<wbr/>History</span>"
    end

    test "shows its badges as markers in the counts row, with their hints" do
      html = render_card("User")

      markers = LazyHTML.query(html, ".ov-card-counts .ov-marker")

      assert Enum.map(markers, &(&1 |> LazyHTML.query(".sr-only") |> LazyHTML.text())) ==
               ["policies", "Ets", "multitenant"]

      assert [policies, ets, multitenant] = Enum.to_list(markers)
      assert [hint] = LazyHTML.attribute(policies, "data-tooltip-text")
      assert hint =~ ~r/^Authorised by \d+ policies/
      assert LazyHTML.attribute(ets, "data-tooltip-title") == ["Ash.DataLayer.Ets"]

      assert LazyHTML.attribute(multitenant, "data-tooltip-text") == [
               "Keeps each tenant's records apart, by its org attribute"
             ]

      assert html |> LazyHTML.query(".ov-pill, .ov-flag, .ov-flags") |> Enum.empty?()
    end
  end

  @spec render_card(String.t()) :: LazyHTML.t()
  defp render_card(label) do
    (&Overview.resource_card/1)
    |> render_component(
      links:
        OverviewComponents.links(%{
          prefix: "/c",
          lens: Architect.make_lens(),
          vertex: %Resource{resource: User}
        }),
      resource: User,
      label: label
    )
    |> LazyHTML.from_fragment()
  end
end
