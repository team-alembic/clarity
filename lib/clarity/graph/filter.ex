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

  alias Clarity.Graph.Util
  alias Clarity.Vertex

  @type filter_fn() :: (Clarity.Graph.t() -> (Vertex.t() -> boolean()))

  @doc """
  Creates a filter that includes vertices within the specified number of steps
  from a center vertex.

  This filter includes vertices reachable within `max_outgoing_steps` forward hops
  OR `max_incoming_steps` backward hops from the center vertex.
  """
  @spec within_steps(Vertex.t(), non_neg_integer(), non_neg_integer()) :: filter_fn()
  def within_steps(center_vertex, max_outgoing_steps, max_incoming_steps) do
    fn graph ->
      center_vertex_id = Vertex.id(center_vertex)

      # Use existing logic to get vertices within steps
      temp_subgraph =
        Util.subgraph_within_steps(
          graph.main_graph,
          center_vertex_id,
          max_outgoing_steps,
          max_incoming_steps
        )

      allowed_vertex_ids = temp_subgraph |> :digraph.vertices() |> MapSet.new()
      :digraph.delete(temp_subgraph)

      fn vertex ->
        vertex_id = Vertex.id(vertex)
        MapSet.member?(allowed_vertex_ids, vertex_id)
      end
    end
  end

  @doc """
  Creates a filter that includes vertices reachable from any of the specified vertices.
  """
  @spec reachable_from([Vertex.t()]) :: filter_fn()
  def reachable_from(source_vertices) do
    fn graph ->
      source_vertex_ids = MapSet.new(source_vertices, &Vertex.id/1)

      # Find all vertices reachable from any source vertex
      for_result =
        for vertex_id <- :digraph.vertices(graph.main_graph),
            MapSet.member?(source_vertex_ids, vertex_id) or
              Enum.any?(source_vertex_ids, fn source_id ->
                :digraph.get_path(graph.main_graph, source_id, vertex_id) != false
              end) do
          vertex_id
        end

      reachable_vertex_ids = MapSet.new(for_result)

      fn vertex ->
        vertex_id = Vertex.id(vertex)
        MapSet.member?(reachable_vertex_ids, vertex_id)
      end
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
  @spec vertex_type([module()]) :: filter_fn()
  def vertex_type(filter_types) when is_list(filter_types) do
    filter_types_set = MapSet.new(filter_types)

    fn _graph ->
      fn vertex ->
        MapSet.member?(filter_types_set, vertex.__struct__)
      end
    end
  end

  @doc """
  Creates a custom filter using a user-provided predicate function.

  The predicate function receives a vertex and should return true if the vertex
  should be included in the filtered graph.
  """
  @spec custom((Vertex.t() -> boolean())) :: filter_fn()
  def custom(predicate_fn) do
    fn _graph -> predicate_fn end
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
  @spec all([filter_fn()]) :: filter_fn()
  def all(filters) when is_list(filters) do
    fn graph ->
      # Prepare all filter predicates
      predicates = Enum.map(filters, & &1.(graph))

      # Return combined predicate that requires all to be true
      fn vertex ->
        Enum.all?(predicates, & &1.(vertex))
      end
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
  @spec any([filter_fn()]) :: filter_fn()
  def any(filters) when is_list(filters) do
    fn graph ->
      # Prepare all filter predicates
      predicates = Enum.map(filters, & &1.(graph))

      # Return combined predicate that requires any to be true
      fn vertex ->
        Enum.any?(predicates, & &1.(vertex))
      end
    end
  end

  @doc """
  Negates a filter using NOT logic.

  A vertex must NOT pass the filter to be included in the result.

  ## Examples

      # Everything except modules
      Filter.negate(Filter.vertex_type([Module]))
  """
  @spec negate(filter_fn()) :: filter_fn()
  def negate(filter) when is_function(filter) do
    fn graph ->
      predicate = filter.(graph)

      # Return negated predicate
      fn vertex ->
        not predicate.(vertex)
      end
    end
  end
end
