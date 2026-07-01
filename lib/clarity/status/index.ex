defmodule Clarity.Status.Index do
  @moduledoc """
  Rolls up per-vertex `Clarity.Status` indicators over the navigation tree.

  For a graph and lens, runs the registered status providers on each vertex,
  keeps the statuses whose `class` the lens surfaces (`lens.status_filter`), and
  aggregates them up the tree so every vertex's entry carries the most severe
  status in its subtree and how many *descendants* are flagged (the count
  excludes the vertex itself — a badge counts what's flagged beneath it). A
  vertex with nothing flagged in its subtree has no entry.

  The walk covers the whole tree, not just the rendered (expanded) nodes, so a
  collapsed parent's badge still reflects what's buried beneath it.
  """

  alias Clarity.Config
  alias Clarity.Graph
  alias Clarity.Perspective.Lens
  alias Clarity.Status
  alias Clarity.Vertex

  require Logger

  @type entry() :: %{severity: Status.severity(), count: non_neg_integer()}
  @type t() :: %{String.t() => entry()}

  @doc """
  Builds the status index for `graph` under `lens`.

  Returns a map of vertex id to `%{severity, count}` for every vertex with a
  flagged status somewhere in its subtree.
  """
  @spec build(Graph.t(), Lens.t()) :: t()
  def build(graph, lens) do
    case Graph.get_vertex(graph, "root") do
      nil -> %{}
      root -> graph |> rollup(root, Config.list_status_providers(), lens, %{}) |> elem(0)
    end
  end

  @doc """
  The worst severity per status class for a single vertex, under `lens`.

  Unlike `build/2` this does not roll up the tree — it returns only the vertex's
  own lens-surfaced statuses, grouped to `%{class => worst_severity}`. Used to
  flag the content tab that explains a status.
  """
  @spec vertex_classes(Graph.t(), Vertex.t(), Lens.t()) :: %{atom() => Status.severity()}
  def vertex_classes(graph, vertex, lens) do
    Config.list_status_providers()
    |> Enum.flat_map(&safe_statuses(&1, vertex, graph))
    |> Enum.filter(lens.status_filter)
    |> Enum.reduce(%{}, fn status, acc ->
      Map.update(acc, status.class, status.severity, &Status.max_severity(&1, status.severity))
    end)
  end

  # Returns the subtree summary `{severity, total_including_self}` for the
  # recursion, while the stored entry's `count` is descendants only (excludes the
  # vertex itself), since a node's badge counts what's flagged *beneath* it.
  @spec rollup(Graph.t(), Vertex.t(), [module()], Lens.t(), t()) ::
          {t(), {Status.severity(), non_neg_integer()} | nil}
  defp rollup(graph, vertex, providers, lens, index) do
    children = graph |> Graph.navigation_children(vertex) |> Map.values() |> List.flatten()

    {index, child_summaries} =
      Enum.reduce(children, {index, []}, fn child, {idx, summaries} ->
        {idx, summary} = rollup(graph, child, providers, lens, idx)
        {idx, [summary | summaries]}
      end)

    child_summaries = Enum.reject(child_summaries, &is_nil/1)
    {own_severity, own_count} = own_status(graph, vertex, providers, lens)

    severity =
      [own_severity | Enum.map(child_summaries, fn {severity, _total} -> severity end)]
      |> Enum.reject(&is_nil/1)
      |> max_severity()

    case severity do
      nil ->
        {index, nil}

      severity ->
        descendants =
          child_summaries |> Enum.map(fn {_severity, total} -> total end) |> Enum.sum()

        entry = %{severity: severity, count: descendants}
        {Map.put(index, Vertex.id(vertex), entry), {severity, own_count + descendants}}
    end
  end

  @spec own_status(Graph.t(), Vertex.t(), [module()], Lens.t()) ::
          {Status.severity() | nil, 0 | 1}
  defp own_status(graph, vertex, providers, lens) do
    statuses =
      providers
      |> Enum.flat_map(&safe_statuses(&1, vertex, graph))
      |> Enum.filter(lens.status_filter)

    case statuses do
      [] -> {nil, 0}
      list -> {list |> Enum.map(& &1.severity) |> max_severity(), 1}
    end
  end

  @spec safe_statuses(module(), Vertex.t(), Graph.t()) :: [Status.t()]
  defp safe_statuses(provider, vertex, graph) do
    provider.statuses(vertex, graph)
  rescue
    error ->
      Logger.warning(
        "Clarity status provider #{inspect(provider)} failed: #{Exception.message(error)}"
      )

      []
  end

  @spec max_severity([Status.severity()]) :: Status.severity() | nil
  defp max_severity([]), do: nil
  defp max_severity([first | rest]), do: Enum.reduce(rest, first, &Status.max_severity/2)
end
