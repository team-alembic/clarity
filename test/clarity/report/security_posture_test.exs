defmodule Clarity.Report.SecurityPostureTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Clarity.Graph
  alias Clarity.Perspective.Lens
  alias Clarity.Perspective.Lensmaker.Architect
  alias Clarity.Report.SecurityPosture
  alias Clarity.Vertex.Ash.Resource
  alias Clarity.Vertex.Root
  alias Demo.Accounts.User

  @spec render_report(Graph.t(), Lens.t()) :: String.t()
  defp render_report(graph, lens) do
    render_component(SecurityPosture, id: "report", graph: graph, lens: lens, prefix: "/c")
  end

  describe "render" do
    test "reviews a resource's posture in prose" do
      graph = Graph.new()
      Graph.add_vertex(graph, %Resource{resource: User}, %Root{})

      html = render_report(graph, Architect.make_lens())

      assert html =~ "Security posture"
      assert html =~ "User"
      # narrative + tables: reachability and a resources roll-up
      assert html =~ "Action reachability"
      assert html =~ "Resources"
      assert html =~ "date_of_birth"
      refute html =~ ~s(phx-click)
      # executive dashboard: KPI cards + two stacked bars
      assert html =~ "Policy coverage"
      assert html =~ "Anonymous reach"
      assert html =~ "data-segment"
    end

    test "says there is nothing to report with no resources" do
      html = render_report(Graph.new(), Architect.make_lens())

      assert html =~ "found any Ash resources"
    end
  end
end
