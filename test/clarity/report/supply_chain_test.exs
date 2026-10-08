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

  describe "render" do
    test "lists an outdated dependency as a low to-do, with the update to run", %{graph: graph, lens: lens} do
      :ets.insert(Clarity.Dependency.Registry, {{:package, "stale"}, %{latest: "2.0.0", retired: []}})
      stale = %Vertex.Application{app: :stale, description: "Stale", version: "1.0.0"}
      Graph.add_vertex(graph, stale, %Root{})

      doc = graph |> render_report(lens) |> doc()

      assert text(doc, ".report-status") == "1 thing to do"
      assert text(doc, ".report-todo[data-severity='low'] .report-todo-title") =~ "Behind their latest release"
      assert text(doc, ".report-todo .report-todo-line") =~ "stale 1.0.0 → 2.0.0"
      assert text(doc, ".report-todo .report-command code") == "mix deps.update stale"
      # links the dependency to its page
      assert doc |> LazyHTML.query("a.report-chip[href='/c/architect/#{Vertex.id(stale)}']") |> Enum.count() == 1
      # compact stats, no explanation up front
      assert LazyHTML.text(doc) =~ "Dependencies"
      refute LazyHTML.text(doc) =~ "This report reviews"
    end

    test "names the dependency that pulls a transitive one in", %{graph: graph, lens: lens} do
      :ets.insert(Clarity.Dependency.Registry, {{:package, "pubsub"}, %{latest: "2.4.0", retired: []}})
      app = %Vertex.Application{app: :app, description: "", version: "0.1.0"}
      phoenix = %Vertex.Application{app: :phoenix, description: "", version: "1.0.0"}
      pubsub = %Vertex.Application{app: :pubsub, description: "", version: "2.3.0"}

      for vertex <- [app, phoenix, pubsub], do: Graph.add_vertex(graph, vertex, %Root{})
      Graph.add_edge(graph, app, phoenix, :dependency)
      Graph.add_edge(graph, phoenix, pubsub, :dependency)

      doc = graph |> render_report(lens) |> doc()

      assert text(doc, ".report-todo .report-todo-line") =~ "pubsub 2.3.0 → 2.4.0 via phoenix"
    end

    test "lists a known vulnerability as a high to-do, with the advisory and its fix", %{graph: graph, lens: lens} do
      add_advisory(graph, %Clarity.Advisory{
        id: "GHSA-xyz",
        package: "vuln",
        summary: "A nasty hole",
        versions: ["1.0.0"]
      })

      doc = graph |> render_report(lens) |> doc()

      todo = ".report-todo[data-severity='high']"
      assert text(doc, "#{todo} .report-todo-title") =~ "Known vulnerabilities"
      assert text(doc, todo) =~ "GHSA-xyz"
      assert text(doc, todo) =~ "A nasty hole"
      assert text(doc, "#{todo} .report-command code") == "mix deps.update vuln"
    end

    test "shows advisory text from the database as text", %{graph: graph, lens: lens} do
      add_advisory(graph, %Clarity.Advisory{
        id: "GHSA-xyz",
        package: "vuln",
        summary: "See ![x](https://tracker.example/t.png) and <a href=\"https://evil.example\">this</a>",
        versions: ["1.0.0"]
      })

      html = render_report(graph, lens)

      assert html =~ "GHSA-xyz"
      refute html =~ "<img"
      refute html =~ ~s(href="https://evil.example")
    end

    test "lists the dependencies it could not check apart from healthy ones", %{
      graph: graph,
      lens: lens
    } do
      :ets.insert(Clarity.Dependency.Registry, {{:package, "fresh"}, %{latest: "1.0.0", retired: []}})
      Graph.add_vertex(graph, %Vertex.Application{app: :fresh, description: "", version: "1.0.0"}, %Root{})
      Graph.add_vertex(graph, %Vertex.Application{app: :local, description: "", version: "0.1.0"}, %Root{})

      doc = graph |> render_report(lens) |> doc()

      assert text(doc, ".report-status-meta") =~ "1 not on Hex, so not checked"
      assert text(doc, "#not-checked .report-chip") == "local"
    end

    test "says the checks are still running before they have results", %{graph: graph, lens: lens} do
      advisories = Application.get_env(:clarity, :advisories)
      Application.put_env(:clarity, :advisories, enabled?: true)
      on_exit(fn -> Application.put_env(:clarity, :advisories, advisories) end)

      Graph.add_vertex(graph, %Vertex.Application{app: :fresh, description: "", version: "1.0.0"}, %Root{})

      doc = graph |> render_report(lens) |> doc()

      assert text(doc, ".report-status[data-tone='pending']") =~ "Still checking"
    end

    test "says there's nothing to do when all clear", %{graph: graph, lens: lens} do
      :ets.insert(Clarity.Dependency.Registry, {{:package, "fresh"}, %{latest: "1.0.0", retired: []}})
      fresh = %Vertex.Application{app: :fresh, description: "Fresh", version: "1.0.0"}
      Graph.add_vertex(graph, fresh, %Root{})

      doc = graph |> render_report(lens) |> doc()

      assert text(doc, ".report-status[data-tone='ok']") == "Nothing to do"
      assert doc |> LazyHTML.query(".report-todo") |> Enum.empty?()
    end
  end
end
