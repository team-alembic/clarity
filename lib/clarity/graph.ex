defmodule Clarity.Graph do
  @moduledoc """
  Manages the graph structure.
  """

  alias Clarity.Graph.Filter
  alias Clarity.Graph.Tree
  alias Clarity.Vertex
  alias Clarity.Vertex.Root

  @derive {Inspect, only: [:readonly]}
  defstruct [:main_graph, :tree_graph, :provenance_graph, :vertices, readonly: false]

  @typedoc """
  The Graph structure.

  It is opaque and should be manipulated only via the provided functions.
  """
  @opaque t() :: %__MODULE__{
            main_graph: :digraph.graph(),
            tree_graph: :digraph.graph(),
            provenance_graph: :digraph.graph(),
            vertices: :ets.tid(),
            readonly: boolean()
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

    graph = %__MODULE__{
      main_graph: main_graph,
      tree_graph: tree_graph,
      provenance_graph: provenance_graph,
      vertices: vertices
    }

    add_root_vertex(graph)
    graph
  end

  @doc """
  Make Graph read-only.

  Further modifications will return {:error, :readonly}.
  """
  @spec seal(t()) :: t()
  def seal(graph), do: %{graph | readonly: true}

  @doc """
  Deletes Graph
  """
  @spec delete(t()) :: :ok | {:error, :readonly}
  def delete(graph)
  def delete(%__MODULE__{readonly: true}), do: {:error, :readonly}

  def delete(%__MODULE__{} = graph) do
    :digraph.delete(graph.main_graph)
    :digraph.delete(graph.tree_graph)
    :digraph.delete(graph.provenance_graph)
    :ets.delete(graph.vertices)
    :ok
  end

  @doc """
  Clears all vertices and edges from the graph.

  Resets graphs to empty state with root vertex.
  """
  @spec clear(t()) :: :ok | {:error, :readonly}
  def clear(graph)
  def clear(%__MODULE__{readonly: true}), do: {:error, :readonly}

  def clear(%__MODULE__{} = graph) do
    # Delete all vertices from graphs using bulk operation
    :digraph.del_vertices(graph.main_graph, :digraph.vertices(graph.main_graph))
    :digraph.del_vertices(graph.tree_graph, :digraph.vertices(graph.tree_graph))
    :digraph.del_vertices(graph.provenance_graph, :digraph.vertices(graph.provenance_graph))

    # Clear vertex table
    :ets.delete_all_objects(graph.vertices)

    # Reset graphs to empty state with root vertex
    add_root_vertex(graph)

    :ok
  end

  @doc """
  Adds a vertex.
  """
  @spec add_vertex(t(), Vertex.t(), Vertex.t()) :: :ok | {:error, :readonly}
  def add_vertex(graph, vertex, caused_by)
  def add_vertex(%__MODULE__{readonly: true}, _vertex, _caused_by), do: {:error, :readonly}

  def add_vertex(%__MODULE__{} = graph, vertex, caused_by) do
    vertex_id = Vertex.unique_id(vertex)
    caused_by_id = Vertex.unique_id(caused_by)

    # Store vertex in ETS table
    :ets.insert(graph.vertices, {vertex_id, vertex})

    # Add vertex ID to graphs (not the vertex struct)
    :digraph.add_vertex(graph.main_graph, vertex_id)
    Tree.add_vertex(graph.tree_graph, vertex_id)
    :digraph.add_vertex(graph.provenance_graph, vertex_id)

    # Add provenance edge: caused_by -> vertex
    :digraph.add_edge(graph.provenance_graph, caused_by_id, vertex_id)

    :ok
  end

  @doc """
  Adds an edge between two vertices.
  """
  @spec add_edge(t(), Vertex.t(), Vertex.t(), :digraph.label()) :: :ok | {:error, :readonly}
  def add_edge(graph, from_vertex, to_vertex, label)

  def add_edge(%__MODULE__{readonly: true}, _from_vertex, _to_vertex, _label),
    do: {:error, :readonly}

  def add_edge(%__MODULE__{} = graph, from_vertex, to_vertex, label) do
    # Convert vertices to IDs
    from_id = Vertex.unique_id(from_vertex)
    to_id = Vertex.unique_id(to_vertex)

    # Add edge to main graph using vertex IDs
    :digraph.add_edge(graph.main_graph, from_id, to_id, label)

    # Add edge to tree graph if it creates a shorter path
    Tree.add_edge(graph.tree_graph, from_id, to_id, label)

    :ok
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
    case :ets.lookup(graph.vertices, vertex_id) do
      [{^vertex_id, vertex_struct}] -> vertex_struct
      [] -> nil
    end
  end

  @doc """
  Gets all vertices.
  """
  @spec vertices(t()) :: [Vertex.t()]
  def vertices(%__MODULE__{} = graph) do
    all_vertices = graph.main_graph |> :digraph.vertices() |> MapSet.new()

    graph.vertices
    |> :ets.tab2list()
    |> Enum.map(&elem(&1, 1))
    |> Enum.filter(&MapSet.member?(all_vertices, Vertex.unique_id(&1)))
  end

  @doc """
  Gets outgoing edges for a vertex.
  """
  @spec out_edges(t(), Vertex.t()) :: [:digraph.edge()]
  def out_edges(%__MODULE__{} = graph, vertex) do
    vertex_id = Vertex.unique_id(vertex)
    :digraph.out_edges(graph.main_graph, vertex_id)
  end

  @doc """
  Gets incoming edges for a vertex.
  """
  @spec in_edges(t(), Vertex.t()) :: [:digraph.edge()]
  def in_edges(%__MODULE__{} = graph, vertex) do
    vertex_id = Vertex.unique_id(vertex)
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
  Purges a vertex and all vertices that were caused by it.
  """
  @spec purge(t(), Vertex.t()) :: {:ok, [Vertex.t()]} | {:error, :readonly}
  def purge(graph, vertex)
  def purge(%__MODULE__{readonly: true}, _vertex), do: {:error, :readonly}

  def purge(%__MODULE__{} = graph, vertex) do
    vertex_id = Vertex.unique_id(vertex)

    # Find all vertices reachable from this vertex (including itself)
    reachable_ids = :digraph_utils.reachable([vertex_id], graph.provenance_graph)

    # Get the vertex structs before deleting them
    purged_vertices =
      reachable_ids
      |> Enum.map(fn id ->
        case :ets.lookup(graph.vertices, id) do
          [{^id, vertex_struct}] -> vertex_struct
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

    {:ok, purged_vertices}
  end

  @doc """
  Gets the shortest path between the root and the vertex.
  Returns false if no path exists.
  """
  @spec breadcrumbs(t(), Vertex.t()) :: [Vertex.t()] | false
  def breadcrumbs(%__MODULE__{} = graph, vertex) do
    to_id = Vertex.unique_id(vertex)

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
    from_id = Vertex.unique_id(from_vertex)
    to_id = Vertex.unique_id(to_vertex)

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
    vertices = graph |> vertices() |> Map.new(&{Vertex.unique_id(&1), &1})
    Tree.build_tree_from_vertex(graph, "root", vertices)
  end

  @doc """
  Creates a filtered subgraph using one or more composable filter functions.
  Returns a new Clarity.Graph instance with the filtered vertices and edges.

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
      |> Enum.map(&Vertex.unique_id/1)

    # Create subgraphs using digraph_utils.subgraph
    filtered_main_graph = :digraph_utils.subgraph(graph.main_graph, included_vertex_ids)
    filtered_tree_graph = :digraph_utils.subgraph(graph.tree_graph, included_vertex_ids)

    %__MODULE__{
      main_graph: filtered_main_graph,
      tree_graph: filtered_tree_graph,
      provenance_graph: graph.provenance_graph,
      vertices: graph.vertices,
      readonly: true
    }
  end

  # Helper function to add root vertex to all graphs
  @spec add_root_vertex(t()) :: :ok
  defp add_root_vertex(graph) do
    root_vertex = %Root{}
    root_id = Vertex.unique_id(root_vertex)

    # Store root vertex in ETS table
    :ets.insert(graph.vertices, {root_id, root_vertex})

    # Add root vertex ID to graphs (special case - root has no provenance)
    :digraph.add_vertex(graph.main_graph, root_id)
    Tree.add_vertex(graph.tree_graph, root_id)
    :digraph.add_vertex(graph.provenance_graph, root_id)

    :ok
  end
end
