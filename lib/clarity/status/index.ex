defmodule Clarity.Status.Index do
  @max_issues 8

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

  Each entry also carries the issues themselves — which vertex, how severe, and
  the message — for the vertex and its subtree, worst first, so a badge's hint
  can say what is wrong without drilling down. It keeps at most
  #{@max_issues} of them, with `severities` counting every issue by severity.
  """

  alias Clarity.Config
  alias Clarity.Graph
  alias Clarity.Perspective.Lens
  alias Clarity.Status
  alias Clarity.Vertex

  require Logger

  @typedoc "One status of one vertex, named for a hint."
  @type issue() :: %{name: String.t(), severity: Status.severity(), message: String.t()}

  @type entry() :: %{
          severity: Status.severity(),
          count: non_neg_integer(),
          issues: [issue()],
          severities: %{Status.severity() => pos_integer()}
        }
  @type t() :: %{String.t() => entry()}

  # A subtree's roll-up: how many of its vertices are flagged (itself
  # included), its worst issues, and how many issues of each severity.
  @typep summary() ::
           {pos_integer(), [issue()], %{Status.severity() => pos_integer()}}

  @doc """
  Builds the status index for `graph` under `lens`.

  Returns a map of vertex id to `%{severity, count, issues, severities}` for
  every vertex with a flagged status somewhere in its subtree.
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

  # Returns the subtree's summary for the recursion, while the stored entry's
  # `count` is descendants only (excludes the vertex itself), since a node's
  # badge counts what's flagged *beneath* it.
  @spec rollup(Graph.t(), Vertex.t(), [module()], Lens.t(), t()) :: {t(), summary() | nil}
  defp rollup(graph, vertex, providers, lens, index) do
    children = graph |> Graph.navigation_children(vertex) |> Map.values() |> List.flatten()

    {index, child_summaries} =
      Enum.reduce(children, {index, []}, fn child, {idx, summaries} ->
        {idx, summary} = rollup(graph, child, providers, lens, idx)
        {idx, [summary | summaries]}
      end)

    own = own_issues(graph, vertex, providers, lens)

    case {own, Enum.reject(child_summaries, &is_nil/1)} do
      {[], []} ->
        {index, nil}

      {own, child_summaries} ->
        descendants = Enum.sum_by(child_summaries, &elem(&1, 0))
        issues = worst_issues([own | Enum.map(child_summaries, &elem(&1, 1))])

        severities = count_severities(own, Enum.map(child_summaries, &elem(&1, 2)))

        entry = %{
          severity: issues |> hd() |> Map.fetch!(:severity),
          count: descendants,
          issues: issues,
          severities: severities
        }

        flagged = if(own == [], do: 0, else: 1) + descendants
        {Map.put(index, Vertex.id(vertex), entry), {flagged, issues, severities}}
    end
  end

  @spec own_issues(Graph.t(), Vertex.t(), [module()], Lens.t()) :: [issue()]
  defp own_issues(graph, vertex, providers, lens) do
    for provider <- providers,
        status <- safe_statuses(provider, vertex, graph),
        lens.status_filter.(status) do
      %{name: Vertex.name(vertex), severity: status.severity, message: status.message}
    end
  end

  # How many issues of each severity: the vertex's own, plus its children's.
  @spec count_severities([issue()], [%{Status.severity() => pos_integer()}]) ::
          %{Status.severity() => pos_integer()}
  defp count_severities(own, child_counts) do
    Enum.reduce(child_counts, Enum.frequencies_by(own, & &1.severity), fn counts, acc ->
      Map.merge(acc, counts, fn _severity, a, b -> a + b end)
    end)
  end

  # The most severe issues of several lists, then by name, at most @max_issues.
  @spec worst_issues([[issue()]]) :: [issue()]
  defp worst_issues(lists) do
    lists
    |> Enum.concat()
    |> Enum.sort_by(&{-Status.rank(&1.severity), &1.name, &1.message})
    |> Enum.take(@max_issues)
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
end
