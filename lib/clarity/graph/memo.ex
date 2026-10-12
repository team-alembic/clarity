defmodule Clarity.Graph.Memo do
  @moduledoc false

  # Results worked out from a graph, kept until the graph changes: under each
  # key, the latest result, and the version of the graph it came from.

  alias Clarity.Graph

  @table __MODULE__

  @spec create_table() :: :ets.table()
  def create_table, do: :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])

  @doc """
  Returns the result kept for `key` and this version of `graph`, or works it
  out with `fun` and keeps it.
  """
  @spec fetch(Graph.t(), term(), (-> result)) :: result when result: term()
  def fetch(graph, key, fun) do
    case :ets.whereis(@table) do
      :undefined ->
        fun.()

      table ->
        key = {Graph.identity(graph), key}
        version = Graph.version(graph)

        case :ets.lookup(table, key) do
          [{^key, ^version, result}] ->
            result

          _stale ->
            result = fun.()
            :ets.insert(table, {key, version, result})
            result
        end
    end
  end
end
