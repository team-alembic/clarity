defmodule Clarity.Graph do
  @moduledoc """
  Manages the graph structure.
  """

  alias Clarity.Graph.Filter
  alias Clarity.Graph.Tree
  alias Clarity.Vertex
  alias Clarity.Vertex.Root

  @derive {Inspect, only: [:owner, :subgraph]}
  @enforce_keys [
    :main_graph,
    :tree_graph,
    :provenance_graph,
    :vertices,
    :update_count,
    :indexes,
    :owner
  ]
  defstruct [
    :main_graph,
    :tree_graph,
    :provenance_graph,
    :vertices,
    :update_count,
    :indexes,
    :owner,
    subgraph: false
  ]

  @type error() :: :subgraphs_are_readonly | :not_owner | :file.posix()
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
            update_count: :ets.tid(),
            indexes: :ets.tid(),
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
    update_count = :ets.new(:update_count, [:set, :protected, read_concurrency: true])
    indexes = :ets.new(:indexes, [:set, :protected, read_concurrency: true])

    :ets.insert(update_count, {:count, 0})

    graph = %__MODULE__{
      main_graph: main_graph,
      tree_graph: tree_graph,
      provenance_graph: provenance_graph,
      vertices: vertices,
      update_count: update_count,
      indexes: indexes,
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

      # Subgraphs shares the vertices ets table, update_count table,
      # indexes table, and the provenance graph with the main graph, so we only
      # delete them for the main graph
      if not graph.subgraph do
        true = :digraph.delete(graph.provenance_graph)
        true = :ets.delete(graph.vertices)
        true = :ets.delete(graph.update_count)
        true = :ets.delete(graph.indexes)
      end

      :ok
    end
  end

  @doc """
  Transfers ownership of all ETS tables to another process.

  Used to hand over a loaded graph from the Cache process to the Server process.
  Returns an updated graph struct with the new owner.
  """
  @spec handover(t(), pid()) :: result(t())
  def handover(%__MODULE__{} = graph, pid) do
    with :ok <- check_writable(graph) do
      # Transfer 3 direct ETS tables
      :ets.give_away(graph.vertices, pid, :graph_handover)
      :ets.give_away(graph.update_count, pid, :graph_handover)
      :ets.give_away(graph.indexes, pid, :graph_handover)

      # Transfer 9 digraph ETS tables (3 per digraph)
      {vtab1, etab1, ntab1, _} = unpack_digraph(graph.main_graph)
      :ets.give_away(vtab1, pid, :graph_handover)
      :ets.give_away(etab1, pid, :graph_handover)
      :ets.give_away(ntab1, pid, :graph_handover)

      {vtab2, etab2, ntab2, _} = unpack_digraph(graph.tree_graph)
      :ets.give_away(vtab2, pid, :graph_handover)
      :ets.give_away(etab2, pid, :graph_handover)
      :ets.give_away(ntab2, pid, :graph_handover)

      {vtab3, etab3, ntab3, _} = unpack_digraph(graph.provenance_graph)
      :ets.give_away(vtab3, pid, :graph_handover)
      :ets.give_away(etab3, pid, :graph_handover)
      :ets.give_away(ntab3, pid, :graph_handover)

      {:ok, %{graph | owner: pid}}
    end
  end

  @doc """
  Clears all vertices and edges from the graph.

  Resets graphs to empty state with root vertex.
  """
  @spec clear(t()) :: result()
  def clear(%__MODULE__{} = graph) do
    with :ok <- check_writable(graph) do
      :digraph.del_vertices(graph.main_graph, :digraph.vertices(graph.main_graph))
      :digraph.del_vertices(graph.tree_graph, :digraph.vertices(graph.tree_graph))
      :digraph.del_vertices(graph.provenance_graph, :digraph.vertices(graph.provenance_graph))

      :ets.delete_all_objects(graph.vertices)
      :ets.delete_all_objects(graph.indexes)

      add_root_vertex(graph)

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
      from_id = Vertex.id(from_vertex)
      to_id = Vertex.id(to_vertex)

      :digraph.add_edge(graph.main_graph, from_id, to_id, label)

      Tree.add_edge(graph.tree_graph, from_id, to_id, label)

      update_degree_index(graph, from_id, label, :out_degree, 1)
      update_degree_index(graph, to_id, label, :in_degree, 1)

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
    :ets.lookup_element(graph.update_count, :count, 2)
  end

  @doc """
  Gets the total in-degree for a vertex across all edge types.
  """
  @spec in_degree(t(), Vertex.t()) :: non_neg_integer()
  def in_degree(%__MODULE__{} = graph, vertex) do
    vertex_id = Vertex.id(vertex)

    graph.main_graph
    |> :digraph.in_edges(vertex_id)
    |> length()
  end

  @doc """
  Gets the in-degree for a vertex for a specific edge type.
  """
  @spec in_degree(t(), Vertex.t(), :digraph.label()) :: non_neg_integer()
  def in_degree(%__MODULE__{} = graph, vertex, label) do
    vertex_id = Vertex.id(vertex)
    key = {vertex_id, label, :in_degree}
    :ets.lookup_element(graph.indexes, key, 2, 0)
  end

  @doc """
  Gets the total out-degree for a vertex across all edge types.
  """
  @spec out_degree(t(), Vertex.t()) :: non_neg_integer()
  def out_degree(%__MODULE__{} = graph, vertex) do
    vertex_id = Vertex.id(vertex)

    graph.main_graph
    |> :digraph.out_edges(vertex_id)
    |> length()
  end

  @doc """
  Gets the out-degree for a vertex for a specific edge type.
  """
  @spec out_degree(t(), Vertex.t(), :digraph.label()) :: non_neg_integer()
  def out_degree(%__MODULE__{} = graph, vertex, label) do
    vertex_id = Vertex.id(vertex)
    key = {vertex_id, label, :out_degree}
    :ets.lookup_element(graph.indexes, key, 2, 0)
  end

  @doc """
  Purges a vertex and all vertices that were caused by it.
  """
  @spec purge(t(), Vertex.t()) :: result([Vertex.t()])
  def purge(%__MODULE__{} = graph, vertex) do
    with :ok <- check_writable(graph) do
      vertex_id = Vertex.id(vertex)

      reachable_ids = :digraph_utils.reachable([vertex_id], graph.provenance_graph)

      purged_vertices =
        reachable_ids
        |> Enum.map(fn id ->
          case :ets.lookup(graph.vertices, id) do
            [{^id, _type, vertex_struct}] -> vertex_struct
            [] -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      Enum.each(reachable_ids, fn id ->
        purge_vertex_indexes(graph, id)
        :ets.delete(graph.vertices, id)
        :digraph.del_vertex(graph.main_graph, id)
        :digraph.del_vertex(graph.tree_graph, id)
        :digraph.del_vertex(graph.provenance_graph, id)
      end)

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

    included_vertex_ids =
      graph
      |> vertices()
      |> Enum.filter(predicate)
      |> Enum.map(&Vertex.id/1)

    filtered_main_graph = :digraph_utils.subgraph(graph.main_graph, included_vertex_ids)
    filtered_tree_graph = :digraph_utils.subgraph(graph.tree_graph, included_vertex_ids)

    %__MODULE__{
      main_graph: filtered_main_graph,
      tree_graph: filtered_tree_graph,
      provenance_graph: graph.provenance_graph,
      vertices: graph.vertices,
      update_count: graph.update_count,
      indexes: graph.indexes,
      owner: self(),
      subgraph: true
    }
  end

  @doc """
  Persists a graph to disk.

  The graph must not be a subgraph.

  Returns `{:error, posix}` on file errors (e.g., `:enoent`, `:eacces`, `:enospc`).
  """
  @spec persist(t(), Path.t()) :: result()
  def persist(%__MODULE__{subgraph: true}, _path), do: {:error, :subgraphs_are_readonly}

  def persist(%__MODULE__{} = graph, path) do
    with :ok <- File.mkdir_p(path),
         :ok <- persist_ets_table(graph.vertices, Path.join(path, "vertices.ets")),
         :ok <- persist_ets_table(graph.update_count, Path.join(path, "update_count.ets")),
         :ok <- persist_ets_table(graph.indexes, Path.join(path, "indexes.ets")),
         :ok <- persist_digraph(graph.main_graph, path, "main"),
         :ok <- persist_digraph(graph.tree_graph, path, "tree") do
      persist_digraph(graph.provenance_graph, path, "provenance")
    end
  end

  @doc """
  Loads a persisted graph from disk.

  > #### Security Warning {: .warning}
  >
  > Only load trusted graphs. ETS tables can contain arbitrary terms including
  > atoms and functions that may crash the VM if malicious.

  Returns `{:error, posix}` on file errors (e.g., `:enoent`, `:eacces`).
  """
  @spec load(Path.t()) :: result(t())
  def load(path) do
    with {:ok, vertices} <- load_ets_table(Path.join(path, "vertices.ets")),
         {:ok, update_count} <- load_ets_table(Path.join(path, "update_count.ets")),
         {:ok, indexes} <- load_ets_table(Path.join(path, "indexes.ets")),
         {:ok, main_graph} <- load_digraph(path, "main", true),
         {:ok, tree_graph} <- load_digraph(path, "tree", false),
         {:ok, provenance_graph} <- load_digraph(path, "provenance", false) do
      graph = %__MODULE__{
        main_graph: main_graph,
        tree_graph: tree_graph,
        provenance_graph: provenance_graph,
        vertices: vertices,
        update_count: update_count,
        indexes: indexes,
        owner: self()
      }

      {:ok, graph}
    end
  end

  @spec persist_ets_table(:ets.tid(), Path.t()) :: :ok | {:error, :file.posix()}
  defp persist_ets_table(table, file_path) do
    case :ets.tab2file(table, String.to_charlist(file_path)) do
      :ok ->
        :ok

      {:error, {:file_error, _path, posix_error}} ->
        {:error, posix_error}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec persist_digraph(:digraph.graph(), Path.t(), String.t()) :: :ok | {:error, :file.posix()}
  defp persist_digraph(digraph, base_path, name) do
    {vtab, etab, ntab, _cyclic} = unpack_digraph(digraph)

    with :ok <- persist_ets_table(vtab, Path.join(base_path, "#{name}_vertices.ets")),
         :ok <- persist_ets_table(etab, Path.join(base_path, "#{name}_edges.ets")) do
      persist_ets_table(ntab, Path.join(base_path, "#{name}_neighbors.ets"))
    end
  end

  @spec load_ets_table(Path.t()) :: {:ok, :ets.tid()} | {:error, :file.posix()}
  defp load_ets_table(file_path) do
    case :ets.file2tab(String.to_charlist(file_path)) do
      {:ok, table} ->
        {:ok, table}

      {:error, {:read_error, {:file_error, _path, posix_error}}} ->
        {:error, posix_error}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec load_digraph(Path.t(), String.t(), boolean()) ::
          {:ok, :digraph.graph()} | {:error, :file.posix()}
  defp load_digraph(base_path, name, cyclic) do
    with {:ok, vtab} <- load_ets_table(Path.join(base_path, "#{name}_vertices.ets")),
         {:ok, etab} <- load_ets_table(Path.join(base_path, "#{name}_edges.ets")),
         {:ok, ntab} <- load_ets_table(Path.join(base_path, "#{name}_neighbors.ets")) do
      {:ok, pack_digraph(vtab, etab, ntab, cyclic)}
    end
  end

  @spec update_degree_index(
          t(),
          String.t(),
          :digraph.label(),
          :in_degree | :out_degree,
          integer()
        ) :: :ok
  defp update_degree_index(graph, vertex_id, label, direction, delta) do
    key = {vertex_id, label, direction}
    :ets.update_counter(graph.indexes, key, delta, {key, 0})
    :ok
  end

  @spec purge_vertex_indexes(t(), String.t()) :: :ok
  defp purge_vertex_indexes(graph, vertex_id) do
    for edge_id <- :digraph.out_edges(graph.main_graph, vertex_id) do
      {^edge_id, ^vertex_id, to_id, label} = :digraph.edge(graph.main_graph, edge_id)
      update_degree_index(graph, to_id, label, :in_degree, -1)
    end

    for edge_id <- :digraph.in_edges(graph.main_graph, vertex_id) do
      {^edge_id, from_id, ^vertex_id, label} = :digraph.edge(graph.main_graph, edge_id)
      update_degree_index(graph, from_id, label, :out_degree, -1)
    end

    :ets.match_delete(graph.indexes, {{vertex_id, :_, :_}, :_})

    :ok
  end

  @spec add_root_vertex(t()) :: :ok
  defp add_root_vertex(graph) do
    root_vertex = %Root{}
    root_id = Vertex.id(root_vertex)

    :ets.insert(graph.vertices, {root_id, Root, root_vertex})

    :digraph.add_vertex(graph.main_graph, root_id)
    Tree.add_vertex(graph.tree_graph, root_id)
    :digraph.add_vertex(graph.provenance_graph, root_id)

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
    :ets.update_counter(graph.update_count, :count, 1, {:count, 0})
  end

  @dialyzer {:nowarn_function, unpack_digraph: 1}
  @spec unpack_digraph(:digraph.graph()) ::
          {:ets.tid(), :ets.tid(), :ets.tid(), boolean()}
  def unpack_digraph(digraph) do
    {:digraph, vtab, etab, ntab, cyclic} = digraph
    {vtab, etab, ntab, cyclic}
  end

  @dialyzer {:nowarn_function, pack_digraph: 4}
  @spec pack_digraph(:ets.tid(), :ets.tid(), :ets.tid(), boolean()) :: :digraph.graph()
  def pack_digraph(vtab, etab, ntab, cyclic) do
    {:digraph, vtab, etab, ntab, cyclic}
  end
end
