defmodule Clarity.Report.SupplyChainTest do
  # async: false — installs the globally-named Clarity.Dependency.Registry ETS table.
  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest

  alias Clarity.Advisory.Source
  alias Clarity.Graph
  alias Clarity.Perspective.Lens
  alias Clarity.Perspective.Lensmaker.Architect
  alias Clarity.Report.Action
  alias Clarity.Report.Components
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

  @spec doc(String.t()) :: LazyHTML.t()
  defp doc(html), do: LazyHTML.from_fragment(html)

  @spec text(LazyHTML.t(), String.t()) :: String.t()
  defp text(doc, selector), do: doc |> LazyHTML.query(selector) |> LazyHTML.text() |> String.split() |> Enum.join(" ")

  @spec add_advisory(Graph.t(), Clarity.Advisory.t()) :: Vertex.Application.t()
  defp add_advisory(graph, advisory) do
    :ets.new(Source, [:named_table, :set, :public])
    :ets.insert(Source, {{:package, "vuln"}, [advisory]})

    vuln = %Vertex.Application{app: :vuln, description: "Vuln", version: "1.0.0"}
    Graph.add_vertex(graph, vuln, %Root{})
    Graph.add_vertex(graph, %Vertex.Advisory{advisory: advisory}, vuln)
    Graph.add_edge(graph, vuln, %Vertex.Advisory{advisory: advisory}, :advisory)
    vuln
  end

  # The one action of the given severity, with its items' text.
  @spec action(Graph.t(), atom()) :: Action.t() | nil
  defp action(graph, severity), do: graph |> SupplyChain.actions([]) |> Enum.find(&(&1.severity == severity))

  @spec items(Action.t()) :: [map()]
  defp items(action), do: Enum.flat_map(action.groups, & &1.items)

  describe "actions/2" do
    test "lists an outdated dependency as a low to-do, with the update to run", %{graph: graph} do
      :ets.insert(Clarity.Dependency.Registry, {{:package, "stale"}, %{latest: "2.0.0", retired: []}})
      stale = %Vertex.Application{app: :stale, description: "Stale", version: "1.0.0"}
      Graph.add_vertex(graph, stale, %Root{})

      action = action(graph, :low)

      assert action.title == "Behind their latest release"
      assert [%{text: "stale", note: "1.0.0 → 2.0.0", id: id}] = items(action)
      assert id == Vertex.id(stale)
      assert action.command == "mix deps.update stale"
    end

    test "names the dependency that pulls a transitive one in", %{graph: graph} do
      :ets.insert(Clarity.Dependency.Registry, {{:package, "pubsub"}, %{latest: "2.4.0", retired: []}})
      app = %Vertex.Application{app: :app, description: "", version: "0.1.0"}
      phoenix = %Vertex.Application{app: :phoenix, description: "", version: "1.0.0"}
      pubsub = %Vertex.Application{app: :pubsub, description: "", version: "2.3.0"}

      for vertex <- [app, phoenix, pubsub], do: Graph.add_vertex(graph, vertex, %Root{})
      Graph.add_edge(graph, app, phoenix, :dependency)
      Graph.add_edge(graph, phoenix, pubsub, :dependency)

      assert [%{note: "2.3.0 → 2.4.0 via phoenix"}] = graph |> action(:low) |> items()
    end

    test "lists a known vulnerability as a high to-do, with the advisory and its fix", %{graph: graph} do
      add_advisory(graph, %Clarity.Advisory{
        id: "GHSA-xyz",
        package: "vuln",
        summary: "A nasty hole",
        versions: ["1.0.0"]
      })

      action = action(graph, :high)

      assert action.title == "Known vulnerabilities"
      assert [%{text: "vuln", details: [detail]}] = items(action)
      assert detail =~ "GHSA-xyz · A nasty hole"
      assert action.command == "mix deps.update vuln"
    end

    test "has nothing to do when all clear", %{graph: graph} do
      :ets.insert(Clarity.Dependency.Registry, {{:package, "fresh"}, %{latest: "1.0.0", retired: []}})
      Graph.add_vertex(graph, %Vertex.Application{app: :fresh, description: "Fresh", version: "1.0.0"}, %Root{})

      assert SupplyChain.actions(graph, []) == []
      assert SupplyChain.pending(graph) == nil
    end
  end

  describe "pending/1" do
    test "says the checks are still running before they have results", %{graph: graph} do
      advisories = Application.get_env(:clarity, :advisories)
      Application.put_env(:clarity, :advisories, enabled?: true)
      on_exit(fn -> Application.put_env(:clarity, :advisories, advisories) end)

      Graph.add_vertex(graph, %Vertex.Application{app: :fresh, description: "", version: "1.0.0"}, %Root{})

      assert SupplyChain.pending(graph) =~ "Still checking"
    end
  end

  test "shows advisory text from the database as text", %{graph: graph, lens: lens} do
    add_advisory(graph, %Clarity.Advisory{
      id: "GHSA-xyz",
      package: "vuln",
      summary: "See ![x](https://tracker.example/t.png) and <a href=\"https://evil.example\">this</a>",
      versions: ["1.0.0"]
    })

    html =
      render_component(&Components.actions/1,
        actions: SupplyChain.actions(graph, []),
        prefix: "/c",
        lens: lens
      )

    assert html =~ "GHSA-xyz"
    refute html =~ "<img"
    refute html =~ ~s(href="https://evil.example")
  end

  describe "render" do
    test "lists every dependency with its standing, without explaining itself", %{graph: graph, lens: lens} do
      :ets.insert(Clarity.Dependency.Registry, {{:package, "stale"}, %{latest: "2.0.0", retired: []}})
      :ets.insert(Clarity.Dependency.Registry, {{:package, "fresh"}, %{latest: "1.0.0", retired: []}})
      Graph.add_vertex(graph, %Vertex.Application{app: :stale, description: "", version: "1.0.0"}, %Root{})
      Graph.add_vertex(graph, %Vertex.Application{app: :fresh, description: "", version: "1.0.0"}, %Root{})
      Graph.add_vertex(graph, %Vertex.Application{app: :local, description: "", version: "0.1.0"}, %Root{})

      doc = graph |> render_report(lens) |> doc()

      rows = doc |> LazyHTML.query("#dependencies tbody tr") |> Enum.map(&(&1 |> LazyHTML.text() |> String.split()))
      # most in need of attention first
      assert Enum.map(rows, &{hd(&1), List.last(&1)}) == [
               {"stale", "outdated"},
               {"fresh", "current"},
               {"local", "checked"}
             ]

      assert text(doc, ".report-status-meta") =~ "1 not on Hex, so not checked"
      # open, to scroll through
      assert doc |> LazyHTML.query("details#dependencies[open]") |> Enum.count() == 1
      refute LazyHTML.text(doc) =~ "This report reviews"
    end
  end
end
