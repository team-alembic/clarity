defmodule Clarity.Report.SecurityPostureTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Clarity.Graph
  alias Clarity.Perspective.Lens
  alias Clarity.Perspective.Lensmaker.Security
  alias Clarity.Report.SecurityPosture
  alias Clarity.Vertex.Ash.Resource
  alias Clarity.Vertex.Root
  alias Demo.Accounts.User

  @spec render_report(Graph.t(), Lens.t()) :: String.t()
  defp render_report(graph, lens) do
    render_component(SecurityPosture, id: "report", graph: graph, lens: lens, prefix: "/c")
  end

  describe "applies?/1" do
    test "only under the security lens" do
      assert SecurityPosture.applies?(Security.make_lens())
      refute SecurityPosture.applies?(%Lens{id: "architect", name: "A", icon: fn -> nil end, filter: true})
    end
  end

  describe "render" do
    test "rolls up a resource's enforcement and exposure" do
      graph = Graph.new()
      Graph.add_vertex(graph, %Resource{resource: User}, %Root{})

      html = render_report(graph, Security.make_lens())

      assert html =~ "User"
      # User has a policy authorizer (governed) and interactive filter chips
      assert html =~ "Governed"
      assert html =~ "Open"
      assert html =~ "Exposed fields"
      assert html =~ ~s(phx-click="filter")
      # resource links must navigate (cross-LiveView), not patch — a patch would
      # crash when clicked from ReportLive into PageLive
      assert html =~ ~s(data-phx-link="redirect")
      refute html =~ ~s(data-phx-link="patch")
    end

    test "shows an empty state with no resources" do
      html = render_report(Graph.new(), Security.make_lens())

      assert html =~ "No Ash resources are visible under this lens"
    end
  end
end
