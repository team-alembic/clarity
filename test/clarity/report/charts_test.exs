defmodule Clarity.Report.ChartsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Clarity.Report.Charts

  describe "stacked_bar/1" do
    test "sizes each segment by its share of the total and lists it in the legend" do
      html =
        render_component(&Charts.stacked_bar/1,
          title: "Dependency health",
          segments: [
            %{label: "Healthy", value: 3, tone: :ok},
            %{label: "Outdated", value: 1, tone: :info},
            %{label: "Retired", value: 0, tone: :warning}
          ]
        )

      document = LazyHTML.from_fragment(html)

      assert document |> LazyHTML.query("figcaption") |> LazyHTML.text() == "Dependency health"

      assert document |> LazyHTML.query("[data-segment]") |> LazyHTML.attribute("style") ==
               ["width: 75.0%", "width: 25.0%"]

      assert document |> LazyHTML.query("[role=img]") |> LazyHTML.attribute("aria-label") ==
               ["Healthy 3, Outdated 1"]

      assert document
             |> LazyHTML.query("li")
             |> Enum.map(&(&1 |> LazyHTML.text() |> String.split() |> Enum.join(" "))) ==
               ["Healthy 3", "Outdated 1"]
    end

    test "renders nothing when every segment is zero" do
      html =
        render_component(&Charts.stacked_bar/1, segments: [%{label: "Healthy", value: 0, tone: :ok}])

      assert String.trim(html) == ""
    end
  end
end
