defmodule Clarity.Report.SupplyChainTest do
  # async: false — installs the globally-named Clarity.Dependency.Registry ETS table.
  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest

  alias Clarity.Graph
  alias Clarity.Perspective.Lens
  alias Clarity.Perspective.Lensmaker.Security
  alias Clarity.Report.SupplyChain
  alias Clarity.Vertex
  alias Clarity.Vertex.Root

  setup do
    :ets.new(Clarity.Dependency.Registry, [:named_table, :set, :public])
    {:ok, graph: Graph.new(), lens: Security.make_lens()}
  end

  @spec render_report(Graph.t(), Lens.t()) :: String.t()
  defp render_report(graph, lens) do
    render_component(SupplyChain, id: "report", graph: graph, lens: lens, prefix: "/c")
  end

  describe "applies?/1" do
    test "only under the security lens" do
      assert SupplyChain.applies?(Security.make_lens())

      refute SupplyChain.applies?(%Lens{
               id: "architect",
               name: "A",
               icon: fn -> nil end,
               filter: true
             })
    end
  end

  describe "render" do
    test "reviews a flagged (outdated) dependency in prose", %{graph: graph, lens: lens} do
      :ets.insert(Clarity.Dependency.Registry, {{:package, "stale"}, %{latest: "2.0.0", retired: []}})
      stale = %Vertex.Application{app: :stale, description: "Stale", version: "1.0.0"}
      Graph.add_vertex(graph, stale, %Root{})

      html = render_report(graph, lens)

      assert html =~ "Supply chain security"
      assert html =~ "stale"
      assert html =~ "2.0.0"
      # dependency hygiene renders as a table with a "Via" column
      assert html =~ "Dependency hygiene"
      assert html =~ "<table"
      assert html =~ "Via"
      assert html =~ "Outdated"
      refute html =~ ~s(phx-click)
      # executive dashboard: KPI cards + a contex SVG chart
      assert html =~ "Dependencies"
      assert html =~ "<svg"
    end

    test "says nothing is flagged when all clear", %{graph: graph, lens: lens} do
      :ets.insert(Clarity.Dependency.Registry, {{:package, "fresh"}, %{latest: "1.0.0", retired: []}})
      fresh = %Vertex.Application{app: :fresh, description: "Fresh", version: "1.0.0"}
      Graph.add_vertex(graph, fresh, %Root{})

      html = render_report(graph, lens)

      assert html =~ "Nothing is flagged"
    end
  end
end
