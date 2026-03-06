defmodule Clarity.Graph.Filter do
  @moduledoc """
  Composable filter functions for graph vertices.

  Filters are higher-order functions that take a graph for preparation
  and return a predicate function that can be called for each vertex.

  ## Example Usage

      # Single filter
      subgraph = Graph.filter(graph, Filter.within_steps(vertex, 2, 1))

      # Composed filters
      filters = [
        Filter.within_steps(vertex, 2, 1),
        Filter.reachable_from(root_vertex),
        Filter.custom(fn v -> String.contains?(Vertex.name(v), "MyApp") end)
      ]
      subgraph = Graph.filter(graph, filters)
  """

  alias Clarity.Graph
  alias Clarity.Graph.Traversal
  alias Clarity.Vertex

  @type filter() :: Graph.query() | (Graph.t() -> Graph.query())

  @doc """
  Creates a filter that includes vertices within the specified number of steps
  from a center vertex.

  This filter includes vertices reachable within `max_outgoing_steps` forward hops
  OR `max_incoming_steps` backward hops from the center vertex.
  """
  @spec within_steps(Vertex.t(), non_neg_integer(), non_neg_integer()) :: filter()
  def within_steps(center_vertex, max_outgoing_steps, max_incoming_steps) do
    fn graph ->
      allowed_vertex_ids =
        graph
        |> Traversal.vertices_within_steps(center_vertex, max_outgoing_steps, max_incoming_steps)
        |> MapSet.to_list()

      {:in, :vertex_id, allowed_vertex_ids}
    end
  end

  @doc """
  Creates a filter that includes vertices reachable from any of the specified vertices.
  """
  @spec reachable_from([Vertex.t()]) :: filter()
  def reachable_from(source_vertices) do
    fn graph ->
      reachable_vertex_ids = Traversal.reachable_from(graph, source_vertices)

      {:in, :vertex_id, reachable_vertex_ids}
    end
  end

  @doc """
  Creates a filter that includes only vertices of the specified types.

  Takes a list of modules (struct types) and includes only vertices whose
  `__struct__` field matches one of the specified types.

  ## Examples

      # Only application vertices
      Filter.vertex_type([Clarity.Vertex.Application])

      # Only modules and applications
      Filter.vertex_type([Clarity.Vertex.Module, Clarity.Vertex.Application])
  """
  @spec vertex_type([module()]) :: filter()
  def vertex_type(filter_types) when is_list(filter_types) do
    {:in, :vertex_type, filter_types}
  end

  @doc """
  Combines multiple filters using AND logic.

  A vertex must pass ALL filters to be included in the result.

  ## Examples

      Filter.all([
        Filter.within_steps(vertex, 2, 0),
        Filter.vertex_type([Module])
      ])
  """
  @spec all([filter()]) :: filter()
  def all(filters) when is_list(filters) do
    fn graph ->
      queries = Enum.map(filters, &evaluate_filter(&1, graph))
      Enum.reduce(queries, fn q, acc -> {:and, acc, q} end)
    end
  end

  @doc """
  Combines multiple filters using OR logic.

  A vertex must pass ANY of the filters to be included in the result.

  ## Examples

      Filter.any([
        Filter.vertex_type([Module]),
        Filter.vertex_type([Application])
      ])
  """
  @spec any([filter()]) :: filter()
  def any(filters) when is_list(filters) do
    fn graph ->
      queries = Enum.map(filters, &evaluate_filter(&1, graph))
      Enum.reduce(queries, fn q, acc -> {:or, acc, q} end)
    end
  end

  @doc """
  Negates a filter using NOT logic.

  A vertex must NOT pass the filter to be included in the result.

  ## Examples

      # Everything except modules
      Filter.negate(Filter.vertex_type([Module]))
  """
  @spec negate(filter()) :: filter()
  def negate(filter) do
    fn graph ->
      query = evaluate_filter(filter, graph)
      {:not, query}
    end
  end

  @spec evaluate_filter(filter(), Graph.t()) :: Graph.query()
  defp evaluate_filter(filter, graph) when is_function(filter), do: filter.(graph)
  defp evaluate_filter(filter, _graph), do: filter
end
