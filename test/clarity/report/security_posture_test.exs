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

  describe "analyse/1" do
    test "reviews a resource's posture in prose" do
      graph = Graph.new()
      Graph.add_vertex(graph, %Resource{resource: User}, %Root{})

      %{markdown: markdown, dashboard: dashboard} = SecurityPosture.analyse(graph)
      markdown = IO.iodata_to_binary(markdown)

      assert markdown =~ "User"
      # narrative + tables: reachability and a resources roll-up
      assert markdown =~ "Action reachability"
      assert markdown =~ "Resources"
      assert markdown =~ "date_of_birth"
      # executive dashboard: KPI cards + two stacked bars
      assert dashboard.resources == 1
      assert [_ | _] = dashboard.coverage
      assert [_ | _] = dashboard.reach
    end

    test "says there is nothing to report with no resources" do
      %{markdown: markdown} = SecurityPosture.analyse(Graph.new())

      assert IO.iodata_to_binary(markdown) =~ "found any Ash resources"
    end
  end

  describe "render" do
    test "shows the analysis is under way until it finishes" do
      html = render_report(Graph.new(), Architect.make_lens())

      assert html =~ "Analysing"
    end
  end
end
