defmodule Clarity.Report.Actions do
  @moduledoc """
  The things to do every report finds, worked out once per change to the
  graph and cached, so the badges on every page don't each run the analysis
  (a report's actions can take a while, e.g. solving every policy).

  The cache holds one graph's entries, keyed by the graph and its update
  count: a graph changed by introspection, or another graph, starts afresh.
  """

  alias Clarity.Graph
  alias Clarity.Report
  alias Clarity.Report.Action

  @key __MODULE__

  @doc """
  The report's actions for `graph`, from the cache when the graph hasn't
  changed since they were worked out.
  """
  @spec for_report(Graph.t(), module(), keyword()) :: [Action.t()]
  def for_report(graph, report, opts \\ []) do
    version = version(graph)
    entry = {report, Keyword.take(opts, [:name_style])}

    case :persistent_term.get(@key, nil) do
      {^version, %{^entry => actions}} ->
        actions

      cached ->
        actions = report.actions(graph, opts)
        entries = if match?({^version, _entries}, cached), do: elem(cached, 1), else: %{}
        :persistent_term.put(@key, {version, Map.put(entries, entry, actions)})
        actions
    end
  end

  @doc "The report's to-dos for `graph`, counted by severity."
  @spec tally(Graph.t(), module()) :: Action.tally()
  def tally(graph, report), do: graph |> for_report(report) |> Action.tally()

  @doc "Each report's tally, for the reports with actions (by default, every registered one)."
  @spec tallies(Graph.t(), [module()]) :: %{module() => Action.tally()}
  def tallies(graph, reports \\ Enum.filter(Report.all(), &Report.actions?/1)) do
    Map.new(reports, &{&1, tally(graph, &1)})
  end

  @doc "Empties the cache."
  @spec clear() :: :ok
  def clear do
    :persistent_term.erase(@key)
    :ok
  end

  # The graph's update-count table names the graph; its count, its version.
  @spec version(Graph.t()) :: {term(), non_neg_integer()}
  defp version(graph), do: {graph.update_count, Graph.get_update_count(graph)}
end
