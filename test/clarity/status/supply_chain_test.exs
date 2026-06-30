defmodule Clarity.Status.SupplyChainTest do
  # async: false — installs the globally-named Clarity.Dependency.Registry ETS table.
  use ExUnit.Case, async: false

  alias Clarity.Graph
  alias Clarity.Status
  alias Clarity.Status.SupplyChain
  alias Clarity.Vertex
  alias Clarity.Vertex.Root

  setup do
    :ets.new(Clarity.Dependency.Registry, [:named_table, :set, :public])
    graph = Graph.new()
    {:ok, graph: graph}
  end

  defp put_summary(package, summary) do
    :ets.insert(Clarity.Dependency.Registry, {{:package, package}, summary})
  end

  defp app(graph, name, version) do
    root = %Root{}
    vertex = %Vertex.Application{app: name, description: to_string(name), version: version}
    Graph.add_vertex(graph, vertex, root)
    vertex
  end

  describe "statuses/2" do
    test "flags a security error for an app with advisories", %{graph: graph} do
      put_summary("mdex", %{latest: "0.13.1", retired: []})
      vertex = app(graph, :mdex, "0.13.1")
      advisory = %Vertex.Advisory{advisory: %Clarity.Advisory{id: "GHSA-x", package: "mdex"}}
      Graph.add_vertex(graph, advisory, vertex)
      Graph.add_edge(graph, vertex, advisory, :advisory)

      assert [%Status{severity: :error, class: :security, source: SupplyChain}] =
               SupplyChain.statuses(vertex, graph)
    end

    test "flags a hygiene warning for a retired installed version", %{graph: graph} do
      put_summary("stale", %{latest: "2.0.0", retired: ["1.0.0"]})
      vertex = app(graph, :stale, "1.0.0")

      assert [%Status{severity: :warning, class: :hygiene}] = SupplyChain.statuses(vertex, graph)
    end

    test "flags a hygiene info for an outdated version", %{graph: graph} do
      put_summary("old", %{latest: "2.0.0", retired: []})
      vertex = app(graph, :old, "1.0.0")

      assert [%Status{severity: :info, class: :hygiene}] = SupplyChain.statuses(vertex, graph)
    end

    test "carries both a security and a hygiene status at once", %{graph: graph} do
      put_summary("both", %{latest: "2.0.0", retired: []})
      vertex = app(graph, :both, "1.0.0")
      advisory = %Vertex.Advisory{advisory: %Clarity.Advisory{id: "GHSA-y", package: "both"}}
      Graph.add_vertex(graph, advisory, vertex)
      Graph.add_edge(graph, vertex, advisory, :advisory)

      severities = graph |> then(&SupplyChain.statuses(vertex, &1)) |> Enum.map(& &1.severity)
      assert :error in severities
      assert :info in severities
    end

    test "returns nothing for an up-to-date app with no advisories", %{graph: graph} do
      put_summary("fresh", %{latest: "1.0.0", retired: []})
      vertex = app(graph, :fresh, "1.0.0")

      assert SupplyChain.statuses(vertex, graph) == []
    end

    test "returns nothing when the registry has no entry", %{graph: graph} do
      vertex = app(graph, :unknown, "1.0.0")

      assert SupplyChain.statuses(vertex, graph) == []
    end

    test "returns nothing for non-application vertices", %{graph: graph} do
      assert SupplyChain.statuses(%Root{}, graph) == []
    end
  end
end
