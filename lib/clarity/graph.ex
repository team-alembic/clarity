defmodule Clarity.Graph do
  @moduledoc """
  Manages the graph structure.
  """

  alias Clarity.Graph.Filter
  alias Clarity.Graph.Tree
  alias Clarity.Vertex
  alias Clarity.Vertex.Root

  @derive {Inspect, only: [:owner, :subgraph]}
  @enforce_keys [:main_graph, :tree_graph, :provenance_graph, :vertices, :owner]
  defstruct [:main_graph, :tree_graph, :provenance_graph, :vertices, :owner, subgraph: false]

  @type error() :: :subgraphs_are_readonly | :not_owner
  @type result() :: :ok | {:error, error()}
  @type result(inner) :: {:ok, inner} | {:error, error()}

  @typedoc """
  The Graph structure.

  It is opaque and should be manipulated only via the provided functions.
  """
  @opaque t() :: %__MODULE__{
            main_graph: :digraph.graph(),
            tree_graph: :digraph.graph(),
            provenance_graph: :digraph.graph(),
            vertices: :ets.tid(),
            owner: pid(),
            subgraph: boolean()
          }

  @doc """
  Creates a new graph.
  """
  @spec new() :: t()
  def new do
    main_graph = :digraph.new()
    tree_graph = :digraph.new([:acyclic])
    provenance_graph = :digraph.new([:acyclic])
    vertices = :ets.new(Vertex, [:set, :protected, read_concurrency: true])

    # Initialize update counter
    :ets.insert(vertices, {:"$update_count", 0})

    graph = %__MODULE__{
      main_graph: main_graph,
      tree_graph: tree_graph,
      provenance_graph: provenance_graph,
      vertices: vertices,
      owner: self()
    }

    add_root_vertex(graph)
    graph
  end

  @doc """
  Deletes Graph
  """
  @spec delete(t()) :: result()
  def delete(%__MODULE__{} = graph) do
    with :ok <- check_owner(graph) do
      true = :digraph.delete(graph.main_graph)
      true = :digraph.delete(graph.tree_graph)

      # Subgraphs shares the vertices ets table and the provenance graph
      # with the main graph, so we only delete them for the main graph
      if not graph.subgraph do
        true = :digraph.delete(graph.provenance_graph)
        true = :ets.delete(graph.vertices)
      end

      :ok
    end
  end

  @doc """
  Clears all vertices and edges from the graph.

  Resets graphs to empty state with root vertex.
  """
  @spec clear(t()) :: result()
  def clear(%__MODULE__{} = graph) do
    with :ok <- check_writable(graph) do
      # Save current counter value before clearing
      current_count = get_update_count(graph)

      # Delete all vertices from graphs using bulk operation
      :digraph.del_vertices(graph.main_graph, :digraph.vertices(graph.main_graph))
      :digraph.del_vertices(graph.tree_graph, :digraph.vertices(graph.tree_graph))
      :digraph.del_vertices(graph.provenance_graph, :digraph.vertices(graph.provenance_graph))

      # Clear vertex table
      :ets.delete_all_objects(graph.vertices)

      # Re-initialize update counter with preserved value
      :ets.insert(graph.vertices, {:"$update_count", current_count})

      # Reset graphs to empty state with root vertex
      add_root_vertex(graph)

      # Increment update counter for the clear operation
      increment_update_count(graph)

      :ok
    end
  end

  @doc """
  Adds a vertex.
  """
  @spec add_vertex(t(), Vertex.t(), Vertex.t()) :: result()
  def add_vertex(%__MODULE__{} = graph, vertex, caused_by) do
    with :ok <- check_writable(graph) do
      vertex_id = Vertex.id(vertex)
      caused_by_id = Vertex.id(caused_by)

      # Store vertex in ETS table
      :ets.insert(graph.vertices, {vertex_id, vertex.__struct__, vertex})

      # Add vertex ID to graphs (not the vertex struct)
      :digraph.add_vertex(graph.main_graph, vertex_id)
      Tree.add_vertex(graph.tree_graph, vertex_id)
      :digraph.add_vertex(graph.provenance_graph, vertex_id)

      # Add provenance edge: caused_by -> vertex
      :digraph.add_edge(graph.provenance_graph, caused_by_id, vertex_id)

      # Increment update counter
      increment_update_count(graph)

      :ok
    end
  end

  @doc """
  Adds an edge between two vertices.
  """
  @spec add_edge(t(), Vertex.t(), Vertex.t(), :digraph.label()) :: result()
  def add_edge(%__MODULE__{} = graph, from_vertex, to_vertex, label) do
    with :ok <- check_writable(graph) do
      # Convert vertices to IDs
      from_id = Vertex.id(from_vertex)
      to_id = Vertex.id(to_vertex)

      # Add edge to main graph using vertex IDs
      :digraph.add_edge(graph.main_graph, from_id, to_id, label)

      # Add edge to tree graph if it creates a shorter path
      Tree.add_edge(graph.tree_graph, from_id, to_id, label)

      # Increment update counter
      increment_update_count(graph)

      :ok
    end
  end

  @doc """
  Gets the total number of vertices.
  """
  @spec vertex_count(t()) :: non_neg_integer()
  def vertex_count(%__MODULE__{} = graph) do
    :digraph.no_vertices(graph.main_graph)
  end

  @doc """
  Looks up a vertex struct by its ID.
  """
  @spec get_vertex(t(), String.t()) :: Vertex.t() | nil
  def get_vertex(%__MODULE__{} = graph, vertex_id) do
    :ets.lookup_element(graph.vertices, vertex_id, 3, nil)
  end

  @type query_option() ::
          {:type, module() | [module()]}
          | {:field_equal, {atom(), any()}}
          | {:field_in, {atom(), [any()]}}
  @type query() :: [query_option()]

  @doc """
  Gets all vertices.
  """
  @spec vertices(t(), query()) :: [Vertex.t()]
  def vertices(%__MODULE__{} = graph, query \\ []) do
    all_vertices = graph.main_graph |> :digraph.vertices() |> MapSet.new()

    graph.vertices
    |> :ets.select(vertex_query_to_ets_match_spec(query))
    |> Enum.filter(&MapSet.member?(all_vertices, Vertex.id(&1)))
  end

  @spec vertex_query_to_ets_match_spec(query :: query()) :: :ets.match_spec()
  defp vertex_query_to_ets_match_spec(query)
  defp vertex_query_to_ets_match_spec([]), do: [{{:"$1", :"$2", :"$3"}, [], [:"$3"]}]

  defp vertex_query_to_ets_match_spec(conditions) do
    filters =
      conditions
      |> Enum.map(fn
        {:field_equal, {field, value}} ->
          {:==, {:map_get, field, :"$3"}, value}

        {:field_in, {_field, []}} ->
          false

        {:field_in, {field, values}} when is_list(values) ->
          values
          |> Enum.map(&{:==, {:map_get, field, :"$3"}, &1})
          |> Enum.reduce(fn a, b -> {:orelse, a, b} end)

        {:type, type} when is_atom(type) ->
          {:==, :"$2", type}

        {:type, types} when is_list(types) ->
          types |> Enum.map(&{:==, :"$2", &1}) |> Enum.reduce(fn a, b -> {:orelse, a, b} end)
      end)
      |> Enum.reduce(fn a, b -> {:andalso, a, b} end)
      |> List.wrap()

    [{{:"$1", :"$2", :"$3"}, filters, [:"$3"]}]
  end

  @doc """
  Gets outgoing edges for a vertex.
  """
  @spec out_edges(t(), Vertex.t()) :: [:digraph.edge()]
  def out_edges(%__MODULE__{} = graph, vertex) do
    vertex_id = Vertex.id(vertex)
    :digraph.out_edges(graph.main_graph, vertex_id)
  end

  @doc """
  Gets incoming edges for a vertex.
  """
  @spec in_edges(t(), Vertex.t()) :: [:digraph.edge()]
  def in_edges(%__MODULE__{} = graph, vertex) do
    vertex_id = Vertex.id(vertex)
    :digraph.in_edges(graph.main_graph, vertex_id)
  end

  @doc """
  Gets all edges IDs.
  """
  @spec edges(t()) :: [:digraph.edge()]
  def edges(%__MODULE__{} = graph) do
    :digraph.edges(graph.main_graph)
  end

  @doc """
  Gets edge information for a given edge ID.
  """
  @spec edge(t(), :digraph.edge()) ::
          {:digraph.edge(), Vertex.t() | nil, Vertex.t() | nil, :digraph.label()}
          | false
  def edge(%__MODULE__{} = graph, edge_id) do
    case :digraph.edge(graph.main_graph, edge_id) do
      {edge_id, from_id, to_id, label} ->
        from_vertex = get_vertex(graph, from_id)
        to_vertex = get_vertex(graph, to_id)
        {edge_id, from_vertex, to_vertex, label}

      false ->
        false
    end
  end

  @doc """
  Gets all vertices that are direct targets of outgoing edges from a vertex.
  """
  @spec out_neighbors(t(), Vertex.t()) :: [Vertex.t()]
  def out_neighbors(%__MODULE__{} = graph, vertex) do
    vertex_id = Vertex.id(vertex)

    graph.main_graph
    |> :digraph.out_neighbours(vertex_id)
    |> Enum.map(&get_vertex(graph, &1))
  end

  @doc """
  Gets all vertices that are direct sources of incoming edges to a vertex.
  """
  @spec in_neighbors(t(), Vertex.t()) :: [Vertex.t()]
  def in_neighbors(%__MODULE__{} = graph, vertex) do
    vertex_id = Vertex.id(vertex)

    graph.main_graph
    |> :digraph.in_neighbours(vertex_id)
    |> Enum.map(&get_vertex(graph, &1))
  end

  @doc """
  Gets the current update count for the graph.

  The count remains stable when no mutations occur and increases monotonically
  when the graph is modified. Use this for change detection to invalidate
  cached subgraphs.

  Do not rely on specific count values or increment amounts as the internal
  update mechanism may change.

  ## Example

      count1 = Graph.get_update_count(graph)
      # ... operations that might modify graph ...
      count2 = Graph.get_update_count(graph)
      
      if count2 > count1, do: # graph changed
  """
  @spec get_update_count(t()) :: pos_integer()
  def get_update_count(%__MODULE__{} = graph) do
    :ets.lookup_element(graph.vertices, :"$update_count", 2)
  end

  @doc """
  Purges a vertex and all vertices that were caused by it.
  """
  @spec purge(t(), Vertex.t()) :: result([Vertex.t()])
  def purge(%__MODULE__{} = graph, vertex) do
    with :ok <- check_writable(graph) do
      vertex_id = Vertex.id(vertex)

      # Find all vertices reachable from this vertex (including itself)
      reachable_ids = :digraph_utils.reachable([vertex_id], graph.provenance_graph)

      # Get the vertex structs before deleting them
      purged_vertices =
        reachable_ids
        |> Enum.map(fn id ->
          case :ets.lookup(graph.vertices, id) do
            [{^id, _type, vertex_struct}] -> vertex_struct
            [] -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      # Remove vertices from all graphs and ETS table
      Enum.each(reachable_ids, fn id ->
        :ets.delete(graph.vertices, id)
        :digraph.del_vertex(graph.main_graph, id)
        :digraph.del_vertex(graph.tree_graph, id)
        :digraph.del_vertex(graph.provenance_graph, id)
      end)

      # Increment update counter
      increment_update_count(graph)

      {:ok, purged_vertices}
    end
  end

  @doc """
  Gets the shortest path between the root and the vertex.
  Returns false if no path exists.
  """
  @spec breadcrumbs(t(), Vertex.t()) :: [Vertex.t()] | false
  def breadcrumbs(%__MODULE__{} = graph, vertex) do
    to_id = Vertex.id(vertex)

    case :digraph.get_short_path(graph.tree_graph, "root", to_id) do
      false -> false
      path_ids -> Enum.map(path_ids, &get_vertex(graph, &1))
    end
  end

  @doc """
  Gets the shortest path between two vertices.
  Returns false if no path exists.
  """
  @spec get_short_path(t(), Vertex.t(), Vertex.t()) ::
          [Vertex.t()] | false
  def get_short_path(%__MODULE__{} = graph, from_vertex, to_vertex) do
    from_id = Vertex.id(from_vertex)
    to_id = Vertex.id(to_vertex)

    case :digraph.get_short_path(graph.main_graph, from_id, to_id) do
      false -> false
      path_ids -> Enum.map(path_ids, &get_vertex(graph, &1))
    end
  end

  @doc """
  Converts the internal tree digraph to a structured tree starting from the root vertex.
  Returns a tree structure with vertices and labeled edges organized hierarchically.
  """
  @spec to_tree(t()) :: Tree.t()
  def to_tree(%__MODULE__{} = graph) do
    vertices = graph |> vertices() |> Map.new(&{Vertex.id(&1), &1})
    Tree.build_tree_from_vertex(graph, "root", vertices)
  end

  @doc """
  Creates a filtered subgraph using one or more composable filter functions.
  Returns a new Clarity.Graph instance with the filtered vertices and edges.

  > #### Graph Memory Management {: .warning}
  >
  > Creating a subgraph will create multiple `:digraph` instances and `:ets`
  > tables. While the main graph is managed by `Clarity`, any subgraphs
  > created via this function must be explicitly deleted using `delete/1`
  > when no longer needed to free up memory.

  ## Examples

      # Single filter
      subgraph = Graph.filter(graph, Filter.within_steps(vertex, 2, 1))

      # Multiple composed filters
      filters = [
        Filter.within_steps(vertex, 2, 1),
        Filter.reachable_from(root_vertex)
      ]
      subgraph = Graph.filter(graph, filters)
  """
  @spec filter(t(), Filter.filter_fn() | [Filter.filter_fn()]) :: t()
  def filter(%__MODULE__{} = graph, filter_or_filters) do
    filter_fn =
      case filter_or_filters do
        filters when is_list(filters) -> Filter.all(filters)
        filter when is_function(filter) -> filter
      end

    predicate = filter_fn.(graph)

    # Apply predicate to all vertices and get their IDs
    included_vertex_ids =
      graph
      |> vertices()
      |> Enum.filter(predicate)
      |> Enum.map(&Vertex.id/1)

    # Create subgraphs using digraph_utils.subgraph
    filtered_main_graph = :digraph_utils.subgraph(graph.main_graph, included_vertex_ids)
    filtered_tree_graph = :digraph_utils.subgraph(graph.tree_graph, included_vertex_ids)

    %__MODULE__{
      main_graph: filtered_main_graph,
      tree_graph: filtered_tree_graph,
      provenance_graph: graph.provenance_graph,
      vertices: graph.vertices,
      owner: self(),
      subgraph: true
    }
  end

  @spec add_root_vertex(t()) :: :ok
  defp add_root_vertex(graph) do
    root_vertex = %Root{}
    root_id = Vertex.id(root_vertex)

    # Store root vertex in ETS table
    :ets.insert(graph.vertices, {root_id, Root, root_vertex})

    # Add root vertex ID to graphs (special case - root has no provenance)
    :digraph.add_vertex(graph.main_graph, root_id)
    Tree.add_vertex(graph.tree_graph, root_id)
    :digraph.add_vertex(graph.provenance_graph, root_id)

    # Increment update counter
    increment_update_count(graph)

    :ok
  end

  @spec check_owner(graph :: t()) :: :ok | {:error, error()}
  defp check_owner(%__MODULE__{owner: owner} = _graph) do
    if owner == self() do
      :ok
    else
      {:error, :not_owner}
    end
  end

  @spec check_writable(graph :: t()) :: :ok | {:error, error()}
  defp check_writable(graph)
  defp check_writable(%__MODULE__{subgraph: true}), do: {:error, :subgraphs_are_readonly}
  defp check_writable(graph), do: check_owner(graph)

  @spec increment_update_count(t()) :: pos_integer()
  defp increment_update_count(%__MODULE__{} = graph) do
    :ets.update_counter(graph.vertices, :"$update_count", 1, {:"$update_count", 0})
  end
end
