defmodule Clarity.Report.SupplyChainTest do
  # async: false — installs the globally-named Clarity.Dependency.Registry ETS table.
  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest

  alias Clarity.Advisory.Source
  alias Clarity.Graph
  alias Clarity.Perspective.Lens
  alias Clarity.Perspective.Lensmaker.Architect
  alias Clarity.Report.SupplyChain
  alias Clarity.Vertex
  alias Clarity.Vertex.Root

  setup do
    :ets.new(Clarity.Dependency.Registry, [:named_table, :set, :public])
    {:ok, graph: Graph.new(), lens: Architect.make_lens()}
  end

  @spec render_report(Graph.t(), Lens.t()) :: String.t()
  defp render_report(graph, lens) do
    render_component(SupplyChain, id: "report", graph: graph, lens: lens, prefix: "/c")
  end

  describe "render" do
    test "reviews a flagged (outdated) dependency in prose", %{graph: graph, lens: lens} do
      :ets.insert(Clarity.Dependency.Registry, {{:package, "stale"}, %{latest: "2.0.0", retired: []}})
      stale = %Vertex.Application{app: :stale, description: "Stale", version: "1.0.0"}
      Graph.add_vertex(graph, stale, %Root{})

      html = render_report(graph, lens)

      assert html =~ "stale"
      assert html =~ "2.0.0"
      # dependency hygiene renders as a table with a "Via" column
      assert html =~ "Dependency hygiene"
      assert html =~ "<table"
      assert html =~ "Via"
      assert html =~ "Outdated"
      refute html =~ ~s(phx-click)
      # executive dashboard: KPI cards + a stacked bar
      assert html =~ "Dependencies"
      assert html =~ "data-segment"
    end

    test "renders security advisories as a table", %{graph: graph, lens: lens} do
      :ets.new(Source, [:named_table, :set, :public])
      advisory = %Clarity.Advisory{id: "GHSA-xyz", package: "vuln", summary: "A nasty hole", versions: ["1.0.0"]}
      :ets.insert(Source, {{:package, "vuln"}, [advisory]})

      vuln = %Vertex.Application{app: :vuln, description: "Vuln", version: "1.0.0"}
      Graph.add_vertex(graph, vuln, %Root{})
      Graph.add_vertex(graph, %Vertex.Advisory{advisory: advisory}, vuln)
      Graph.add_edge(graph, vuln, %Vertex.Advisory{advisory: advisory}, :advisory)

      html = render_report(graph, lens)

      assert html =~ "Security advisories"
      assert html =~ "<table"
      assert html =~ "GHSA-xyz"
      assert html =~ "A nasty hole"
    end

    test "escapes markdown in advisory text from the database", %{graph: graph, lens: lens} do
      :ets.new(Source, [:named_table, :set, :public])

      advisory = %Clarity.Advisory{
        id: "GHSA-xyz",
        package: "vuln",
        summary: "See ![x](https://tracker.example/t.png) and [this](https://evil.example)",
        versions: ["1.0.0"]
      }

      :ets.insert(Source, {{:package, "vuln"}, [advisory]})
      vuln = %Vertex.Application{app: :vuln, description: "Vuln", version: "1.0.0"}
      Graph.add_vertex(graph, vuln, %Root{})
      Graph.add_vertex(graph, %Vertex.Advisory{advisory: advisory}, vuln)
      Graph.add_edge(graph, vuln, %Vertex.Advisory{advisory: advisory}, :advisory)

      html = render_report(graph, lens)

      assert html =~ "GHSA-xyz"
      refute html =~ "<img"
      refute html =~ ~s(href="https://evil.example")
    end

    test "counts dependencies it could not check apart from healthy ones", %{
      graph: graph,
      lens: lens
    } do
      :ets.insert(Clarity.Dependency.Registry, {{:package, "fresh"}, %{latest: "1.0.0", retired: []}})
      Graph.add_vertex(graph, %Vertex.Application{app: :fresh, description: "", version: "1.0.0"}, %Root{})
      Graph.add_vertex(graph, %Vertex.Application{app: :local, description: "", version: "0.1.0"}, %Root{})

      html = render_report(graph, lens)

      assert html =~ "Not checked"
      assert html =~ "could not be checked"
    end

    test "says the checks are still running before they have results", %{graph: graph, lens: lens} do
      advisories = Application.get_env(:clarity, :advisories)
      Application.put_env(:clarity, :advisories, enabled?: true)
      on_exit(fn -> Application.put_env(:clarity, :advisories, advisories) end)

      Graph.add_vertex(graph, %Vertex.Application{app: :fresh, description: "", version: "1.0.0"}, %Root{})

      html = render_report(graph, lens)

      assert html =~ "still checking"
      refute html =~ "Nothing is flagged"
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
