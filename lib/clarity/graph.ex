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
  def handover(graph, pid)

  def handover(%__MODULE__{subgraph: true} = graph, pid) do
    with :ok <- check_owner(graph) do
      # For subgraphs, only transfer the unique digraph tables (main_graph and tree_graph)
      # The vertices, update_count, indexes, and provenance_graph are shared with the main graph
      {vtab1, etab1, ntab1, _} = unpack_digraph(graph.main_graph)
      :ets.give_away(vtab1, pid, :graph_handover)
      :ets.give_away(etab1, pid, :graph_handover)
      :ets.give_away(ntab1, pid, :graph_handover)

      {vtab2, etab2, ntab2, _} = unpack_digraph(graph.tree_graph)
      :ets.give_away(vtab2, pid, :graph_handover)
      :ets.give_away(etab2, pid, :graph_handover)
      :ets.give_away(ntab2, pid, :graph_handover)

      {:ok, %{graph | owner: pid}}
    end
  end

  def handover(%__MODULE__{} = graph, pid) do
    with :ok <- check_owner(graph) do
      # For main graphs, transfer all ETS tables
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

  @type query_subject() :: :vertex_type | :vertex_id | {:field, atom()}

  @type query() ::
          {:and, query(), query()}
          | {:or, query(), query()}
          | {:not, query()}
          | {:==, query_subject(), term()}
          | {:!=, query_subject(), term()}
          | {:in, query_subject(), [term()]}
          | boolean()

  @doc """
  Gets all vertices matching the query.

  ## Query Syntax

  Queries support complex boolean expressions using operations, operators, and fields.

  ### Operations
  - `{:and, query1, query2}` - Both queries must match
  - `{:or, query1, query2}` - Either query must match
  - `{:not, query}` - Query must not match

  ### Operators
  - `{:==, field, value}` - Field equals value
  - `{:!=, field, value}` - Field does not equal value
  - `{:in, field, values}` - Field is in list of values

  ### Fields
  - `:vertex_type` - The module of the vertex (e.g., `Application`, `Module`)
  - `:vertex_id` - The unique ID string of the vertex
  - `{:field, :field_name}` - A field within the vertex struct (e.g., `{:field, :app}`, `{:field, :module}`)

  ## Examples

      # All Application vertices
      Graph.vertices(graph, {:==, :vertex_type, Application})

      # Application OR Root vertices
      Graph.vertices(graph, {:or,
        {:==, :vertex_type, Application},
        {:==, :vertex_type, Root}
      })

      # Same as above, using :in
      Graph.vertices(graph, {:in, :vertex_type, [Application, Root]})

      # Complex: Root/Application OR (Module with specific ID)
      Graph.vertices(graph, {:or,
        {:in, :vertex_type, [Root, Application]},
        {:and, {:==, :vertex_type, Module}, {:==, :vertex_id, "module:Foo"}}
      })

      # All vertices except Root
      Graph.vertices(graph, {:not, {:==, :vertex_type, Root}})

      # Query by field value
      Graph.vertices(graph, {:and,
        {:==, :vertex_type, Application},
        {:==, {:field, :app}, :my_app}
      })

      # All vertices (default)
      Graph.vertices(graph, true)
      Graph.vertices(graph)
  """
  @spec vertices(t(), query()) :: [Vertex.t()]
  def vertices(%__MODULE__{} = graph, query \\ true) do
    all_vertices = graph.main_graph |> :digraph.vertices() |> MapSet.new()

    graph.vertices
    |> :ets.select(vertex_query_to_ets_match_spec(query, :"$3"))
    |> Enum.filter(&MapSet.member?(all_vertices, Vertex.id(&1)))
  end

  @doc """
  Gets all unique vertex types present in the graph.

  Returns a list of modules representing the types of vertices in the graph.
  """
  @spec available_vertex_types(t()) :: [module()]
  def available_vertex_types(%__MODULE__{} = graph) do
    graph.main_graph
    |> :digraph.vertices()
    |> Enum.map(&:ets.lookup_element(graph.vertices, &1, 2))
    |> Enum.uniq()
    |> Enum.sort()
  end

  @spec vertex_ids(t(), query()) :: [Vertex.t()]
  defp vertex_ids(%__MODULE__{} = graph, query) do
    all_vertices = graph.main_graph |> :digraph.vertices() |> MapSet.new()

    graph.vertices
    |> :ets.select(vertex_query_to_ets_match_spec(query, :"$1"))
    |> MapSet.new()
    |> MapSet.intersection(all_vertices)
    |> MapSet.to_list()
  end

  @spec vertex_query_to_ets_match_spec(query :: query(), select :: atom()) :: :ets.match_spec()
  defp vertex_query_to_ets_match_spec(query, select)
  defp vertex_query_to_ets_match_spec(true, select), do: [{{:"$1", :"$2", :"$3"}, [], [select]}]

  defp vertex_query_to_ets_match_spec(query, select) do
    condition = query_to_match_condition(query)
    [{{:"$1", :"$2", :"$3"}, [condition], [select]}]
  end

  @spec query_to_match_condition(query()) :: term()
  defp query_to_match_condition(true), do: true
  defp query_to_match_condition(false), do: false

  defp query_to_match_condition({:and, q1, q2}) do
    {:andalso, query_to_match_condition(q1), query_to_match_condition(q2)}
  end

  defp query_to_match_condition({:or, q1, q2}) do
    {:orelse, query_to_match_condition(q1), query_to_match_condition(q2)}
  end

  defp query_to_match_condition({:not, q}) do
    {:not, query_to_match_condition(q)}
  end

  defp query_to_match_condition({:==, subject, value}) do
    {:==, query_subject(subject), value}
  end

  defp query_to_match_condition({:!=, subject, value}) do
    {:"/=", query_subject(subject), value}
  end

  defp query_to_match_condition({:in, _field, []}) do
    false
  end

  defp query_to_match_condition({:in, field, values}) when is_list(values) do
    values
    |> Enum.map(&query_to_match_condition({:==, field, &1}))
    |> Enum.reduce(fn a, b -> {:orelse, a, b} end)
  end

  @spec query_subject(query_subject()) :: term()
  defp query_subject(:vertex_type), do: :"$2"
  defp query_subject(:vertex_id), do: :"$1"
  defp query_subject({:field, field}), do: {:map_get, field, :"$3"}

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
        |> Enum.map(&lookup_vertex_struct(graph, &1))
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

  @spec lookup_vertex_struct(t(), String.t()) :: Vertex.t() | nil
  defp lookup_vertex_struct(graph, id) do
    case :ets.lookup(graph.vertices, id) do
      [{^id, _type, vertex_struct}] -> vertex_struct
      [] -> nil
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
  Gets the direct children of a vertex in the tree graph, grouped by edge label.

  Returns a map where keys are edge labels and values are lists of child vertices,
  sorted by vertex name for consistent ordering.

  ## Examples

      children = Graph.navigation_children(graph, root_vertex)
      # Returns: %{:application => [app1, app2], :module => [mod1]}
  """
  @spec navigation_children(t(), Vertex.t()) :: %{:digraph.label() => [Vertex.t()]}
  def navigation_children(%__MODULE__{} = graph, vertex) do
    vertex_id = Vertex.id(vertex)

    graph.tree_graph
    |> :digraph.out_edges(vertex_id)
    |> Enum.map(fn edge_id ->
      {_, _, to_vertex_id, label} = :digraph.edge(graph.tree_graph, edge_id)
      {label, to_vertex_id}
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Map.new(fn {label, vertex_ids} ->
      children =
        vertex_ids
        |> Enum.map(&get_vertex(graph, &1))
        |> Enum.sort_by(&Vertex.name/1)

      {label, children}
    end)
  end

  @doc """
  Creates a filtered subgraph using a composable filter.
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
      filter = Filter.all([
        Filter.within_steps(vertex, 2, 1),
        Filter.reachable_from([root_vertex])
      ])
      subgraph = Graph.filter(graph, filter)
  """
  @spec filter(t(), Filter.filter() | [Filter.filter()]) :: t()
  def filter(%__MODULE__{} = graph, filters) when is_list(filters) do
    filter(graph, Filter.all(filters))
  end

  def filter(%__MODULE__{} = graph, filter) do
    query = if is_function(filter), do: filter.(graph), else: filter

    included_vertex_ids = vertex_ids(graph, query)

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
