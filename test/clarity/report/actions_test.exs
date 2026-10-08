defmodule Clarity.Report.ActionsTest do
  # async: false — the cache is global, in :persistent_term.
  use ExUnit.Case, async: false

  alias Clarity.Graph
  alias Clarity.Report.Action
  alias Clarity.Report.Actions
  alias Clarity.Vertex.Ash.Resource
  alias Clarity.Vertex.Root

  doctest Action

  # A report whose actions count how often it was asked.
  defmodule CountingReport do
    @moduledoc false
    @behaviour Clarity.Report

    @impl Clarity.Report
    def name, do: "Counting"

    @impl Clarity.Report
    def actions(_graph, _opts) do
      send(self(), :asked)

      [
        %Action{severity: :high, title: "a", groups: [%{items: [%{text: "x"}]}]},
        %Action{severity: :low, title: "b", groups: [%{items: [%{text: "y"}, %{text: "z"}]}]}
      ]
    end
  end

  setup do
    Actions.clear()
    :ok
  end

  test "counts a report's to-dos by severity, one per item" do
    assert Actions.tally(Graph.new(), CountingReport) == %{high: 1, medium: 0, low: 2, total: 3, worst: :high}
  end

  test "works a report's actions out once per change to the graph" do
    graph = Graph.new()

    Actions.for_report(graph, CountingReport)
    Actions.for_report(graph, CountingReport)

    assert_received :asked
    refute_received :asked

    Graph.add_vertex(graph, %Resource{resource: Demo.Accounts.User}, %Root{})
    Actions.for_report(graph, CountingReport)

    assert_received :asked
  end

  test "keeps each graph's actions apart" do
    Actions.for_report(Graph.new(), CountingReport)
    Actions.for_report(Graph.new(), CountingReport)

    assert_received :asked
    assert_received :asked
  end

  test "tallies every report with actions" do
    tallies = Actions.tallies(Graph.new(), [CountingReport])

    assert tallies == %{CountingReport => %{high: 1, medium: 0, low: 2, total: 3, worst: :high}}
    assert Action.sum(Map.values(tallies)).total == 3
  end
end
