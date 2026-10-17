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
    :view,
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
            owner: pid() | nil,
            view: MapSet.t(String.t()) | nil,
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
  def delete(graph)

  # A view shares the graph it was made from, so has nothing of its own.
  def delete(%__MODULE__{view: view} = graph) when view != nil, do: check_owner(graph)

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

  def handover(%__MODULE__{view: view} = graph, pid) when view != nil do
    with :ok <- check_owner(graph) do
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

      case :digraph.add_edge(graph.main_graph, from_id, to_id, label) do
        {:error, _reason} ->
          :ok

        _edge ->
          Tree.add_edge(graph.tree_graph, from_id, to_id, label)

          update_degree_index(graph, from_id, label, :out_degree, 1)
          update_degree_index(graph, to_id, label, :in_degree, 1)

          increment_update_count(graph)

          :ok
      end
    end
  end

  @doc """
  Gets the total number of vertices.
  """
  @spec vertex_count(t()) :: non_neg_integer()
  def vertex_count(%__MODULE__{view: nil} = graph), do: :digraph.no_vertices(graph.main_graph)
  def vertex_count(%__MODULE__{view: view}), do: MapSet.size(view)

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
  def vertices(graph, query \\ true)

  # The full graph has every vertex the table has.
  def vertices(%__MODULE__{view: nil} = graph, query) do
    :ets.select(graph.vertices, vertex_query_to_ets_match_spec(query, :"$3"))
  end

  # A view shares the full graph's table, so keeps only its own vertices.
  def vertices(%__MODULE__{view: view} = graph, true) do
    for id <- view, vertex = get_vertex(graph, id), do: vertex
  end

  def vertices(%__MODULE__{view: view} = graph, query) do
    graph.vertices
    |> :ets.select(vertex_query_to_ets_match_spec(query, {{:"$1", :"$3"}}))
    |> Enum.flat_map(fn {id, vertex} ->
      if MapSet.member?(view, id), do: [vertex], else: []
    end)
  end

  @doc """
  Gets all unique vertex types present in the graph.

  Returns a list of modules representing the types of vertices in the graph.
  """
  @spec available_vertex_types(t()) :: [module()]
  def available_vertex_types(%__MODULE__{view: nil} = graph) do
    graph.vertices
    |> :ets.select([{{:_, :"$2", :_}, [], [:"$2"]}])
    |> Enum.uniq()
    |> Enum.sort()
  end

  def available_vertex_types(%__MODULE__{view: view} = graph) do
    view
    |> Enum.map(&:ets.lookup_element(graph.vertices, &1, 2, nil))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @spec vertex_ids(t(), query()) :: [String.t()]
  defp vertex_ids(%__MODULE__{view: nil} = graph, query) do
    :ets.select(graph.vertices, vertex_query_to_ets_match_spec(query, :"$1"))
  end

  defp vertex_ids(%__MODULE__{view: view}, true), do: MapSet.to_list(view)

  defp vertex_ids(%__MODULE__{view: view} = graph, query) do
    graph.vertices
    |> :ets.select(vertex_query_to_ets_match_spec(query, :"$1"))
    |> Enum.filter(&MapSet.member?(view, &1))
  end

  @spec vertex_query_to_ets_match_spec(query :: query(), select :: atom() | tuple()) ::
          :ets.match_spec()
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

  # One map lookup rather than a comparison per value: a chain of comparisons is
  # slow for many values, and deep enough to exceed ETS's match spec limits.
  defp query_to_match_condition({:in, field, values}) when is_list(values) do
    {:is_map_key, query_subject(field), {:const, Map.from_keys(values, true)}}
  end

  @spec query_subject(query_subject()) :: term()
  defp query_subject(:vertex_type), do: :"$2"
  defp query_subject(:vertex_id), do: :"$1"
  defp query_subject({:field, field}), do: {:map_get, field, :"$3"}

  @doc """
  Gets outgoing edges for a vertex.
  """
  @spec out_edges(t(), Vertex.t()) :: [:digraph.edge()]
  def out_edges(%__MODULE__{} = graph, vertex), do: vertex_edges(graph, Vertex.id(vertex), :out)

  @doc """
  Gets incoming edges for a vertex.
  """
  @spec in_edges(t(), Vertex.t()) :: [:digraph.edge()]
  def in_edges(%__MODULE__{} = graph, vertex), do: vertex_edges(graph, Vertex.id(vertex), :in)

  # The edges out of, or into, a vertex: in a view, those to or from the view's
  # other vertices.
  @spec vertex_edges(t(), String.t(), :out | :in) :: [:digraph.edge()]
  defp vertex_edges(%__MODULE__{view: nil} = graph, vertex_id, :out),
    do: :digraph.out_edges(graph.main_graph, vertex_id)

  defp vertex_edges(%__MODULE__{view: nil} = graph, vertex_id, :in),
    do: :digraph.in_edges(graph.main_graph, vertex_id)

  defp vertex_edges(%__MODULE__{view: view} = graph, vertex_id, direction) do
    if MapSet.member?(view, vertex_id) do
      %{graph | view: nil}
      |> vertex_edges(vertex_id, direction)
      |> Enum.filter(&other_end_in_view?(graph, &1, direction))
    else
      []
    end
  end

  @spec other_end_in_view?(t(), :digraph.edge(), :out | :in) :: boolean()
  defp other_end_in_view?(graph, edge_id, direction) do
    case :digraph.edge(graph.main_graph, edge_id) do
      {_edge_id, _from_id, to_id, _label} when direction == :out -> in_view?(graph, to_id)
      {_edge_id, from_id, _to_id, _label} -> in_view?(graph, from_id)
      false -> false
    end
  end

  @doc false
  # The ids of a vertex's neighbours, out or in: in a view, those in the view.
  @spec neighbour_ids(t(), String.t(), :out | :in) :: [String.t()]
  def neighbour_ids(%__MODULE__{view: nil} = graph, vertex_id, :out),
    do: :digraph.out_neighbours(graph.main_graph, vertex_id)

  def neighbour_ids(%__MODULE__{view: nil} = graph, vertex_id, :in),
    do: :digraph.in_neighbours(graph.main_graph, vertex_id)

  def neighbour_ids(%__MODULE__{view: view} = graph, vertex_id, direction) do
    if MapSet.member?(view, vertex_id) do
      %{graph | view: nil}
      |> neighbour_ids(vertex_id, direction)
      |> Enum.filter(&MapSet.member?(view, &1))
    else
      []
    end
  end

  @doc false
  # Whether the graph has the vertex with this id.
  @spec vertex_id?(t(), String.t()) :: boolean()
  def vertex_id?(%__MODULE__{view: nil} = graph, vertex_id),
    do: :digraph.vertex(graph.main_graph, vertex_id) != false

  def vertex_id?(%__MODULE__{view: view}, vertex_id), do: MapSet.member?(view, vertex_id)

  @doc """
  Gets all edges IDs.
  """
  @spec edges(t()) :: [:digraph.edge()]
  def edges(%__MODULE__{view: nil} = graph), do: :digraph.edges(graph.main_graph)

  def edges(%__MODULE__{view: view} = graph),
    do: for(vertex_id <- view, edge_id <- vertex_edges(graph, vertex_id, :out), do: edge_id)

  @doc """
  Gets edge information for a given edge ID.
  """
  @spec edge(t(), :digraph.edge()) ::
          {:digraph.edge(), Vertex.t() | nil, Vertex.t() | nil, :digraph.label()}
          | false
  def edge(%__MODULE__{} = graph, edge_id) do
    with {edge_id, from_id, to_id, label} <- :digraph.edge(graph.main_graph, edge_id),
         true <- in_view?(graph, from_id) and in_view?(graph, to_id) do
      {edge_id, get_vertex(graph, from_id), get_vertex(graph, to_id), label}
    end
  end

  @spec in_view?(t(), String.t()) :: boolean()
  defp in_view?(%__MODULE__{view: nil}, _vertex_id), do: true
  defp in_view?(%__MODULE__{view: view}, vertex_id), do: MapSet.member?(view, vertex_id)

  @doc """
  Gets all vertices that are direct targets of outgoing edges from a vertex.
  """
  @spec out_neighbors(t(), Vertex.t()) :: [Vertex.t()]
  def out_neighbors(%__MODULE__{} = graph, vertex) do
    graph
    |> neighbour_ids(Vertex.id(vertex), :out)
    |> Enum.map(&get_vertex(graph, &1))
  end

  @doc """
  Gets all vertices that are direct sources of incoming edges to a vertex.
  """
  @spec in_neighbors(t(), Vertex.t()) :: [Vertex.t()]
  def in_neighbors(%__MODULE__{} = graph, vertex) do
    graph
    |> neighbour_ids(Vertex.id(vertex), :in)
    |> Enum.map(&get_vertex(graph, &1))
  end

  @doc """
  Gets the targets of a vertex's outgoing edges with `label`, each once.
  """
  @spec out_neighbors(t(), Vertex.t(), :digraph.label()) :: [Vertex.t()]
  def out_neighbors(%__MODULE__{} = graph, vertex, label) do
    targets =
      for edge_id <- out_edges(graph, vertex),
          {_edge_id, _from, %{} = to, ^label} <- [edge(graph, edge_id)],
          do: to

    Enum.uniq_by(targets, &Vertex.id/1)
  end

  @doc """
  Gets the sources of a vertex's incoming edges with `label`, each once.
  """
  @spec in_neighbors(t(), Vertex.t(), :digraph.label()) :: [Vertex.t()]
  def in_neighbors(%__MODULE__{} = graph, vertex, label) do
    sources =
      for edge_id <- in_edges(graph, vertex),
          {_edge_id, %{} = from, _to, ^label} <- [edge(graph, edge_id)],
          do: from

    Enum.uniq_by(sources, &Vertex.id/1)
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
  def in_degree(%__MODULE__{} = graph, vertex), do: length(in_edges(graph, vertex))

  @doc """
  Gets the in-degree for a vertex for a specific edge type.
  """
  @spec in_degree(t(), Vertex.t(), :digraph.label()) :: non_neg_integer()
  def in_degree(%__MODULE__{view: view} = graph, vertex, label) when view != nil do
    count_labelled(graph.main_graph, in_edges(graph, vertex), label)
  end

  def in_degree(%__MODULE__{} = graph, vertex, label) do
    vertex_id = Vertex.id(vertex)
    key = {vertex_id, label, :in_degree}
    :ets.lookup_element(graph.indexes, key, 2, 0)
  end

  @doc """
  Gets the total out-degree for a vertex across all edge types.
  """
  @spec out_degree(t(), Vertex.t()) :: non_neg_integer()
  def out_degree(%__MODULE__{} = graph, vertex), do: length(out_edges(graph, vertex))

  @doc """
  Gets the out-degree for a vertex for a specific edge type.
  """
  @spec out_degree(t(), Vertex.t(), :digraph.label()) :: non_neg_integer()
  def out_degree(%__MODULE__{view: view} = graph, vertex, label) when view != nil do
    count_labelled(graph.main_graph, out_edges(graph, vertex), label)
  end

  def out_degree(%__MODULE__{} = graph, vertex, label) do
    vertex_id = Vertex.id(vertex)
    key = {vertex_id, label, :out_degree}
    :ets.lookup_element(graph.indexes, key, 2, 0)
  end

  # Views share the full graph's degree indexes, so they count their own edges
  # instead.
  @spec count_labelled(:digraph.graph(), [:digraph.edge()], :digraph.label()) ::
          non_neg_integer()
  defp count_labelled(digraph, edges, label) do
    Enum.count(edges, &match?({_edge, _from, _to, ^label}, :digraph.edge(digraph, &1)))
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
    with path_ids when is_list(path_ids) <- tree_path(graph.tree_graph, Vertex.id(vertex), []),
         true <- Enum.all?(path_ids, &vertex_id?(graph, &1)) do
      Enum.map(path_ids, &get_vertex(graph, &1))
    else
      _no_path -> false
    end
  end

  # In the tree, every vertex but the root has one parent, so the path to it
  # is its parents', back to the root.
  @spec tree_path(:digraph.graph(), String.t(), [String.t()]) :: [String.t()] | nil
  defp tree_path(_tree_graph, "root", path), do: ["root" | path]

  defp tree_path(tree_graph, vertex_id, path) do
    # The server may move a vertex to a shorter path between the two reads,
    # deleting the edge just found.
    with [edge] <- :digraph.in_edges(tree_graph, vertex_id),
         {_edge, parent_id, _vertex_id, _label} <- :digraph.edge(tree_graph, edge) do
      tree_path(tree_graph, parent_id, [vertex_id | path])
    else
      _none -> nil
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

    case short_path(graph, from_id, to_id) do
      false -> false
      path_ids -> Enum.map(path_ids, &get_vertex(graph, &1))
    end
  end

  @spec short_path(t(), String.t(), String.t()) :: [String.t()] | false
  defp short_path(%__MODULE__{view: nil} = graph, from_id, to_id),
    do: :digraph.get_short_path(graph.main_graph, from_id, to_id)

  # Breadth first through the view's vertices, as :digraph.get_short_path/3
  # does through all of them.
  defp short_path(graph, from_id, to_id) do
    if vertex_id?(graph, from_id) and vertex_id?(graph, to_id),
      do: bfs_path(graph, :queue.from_list([from_id]), %{from_id => nil}, to_id),
      else: false
  end

  @spec bfs_path(t(), :queue.queue(String.t()), %{String.t() => String.t() | nil}, String.t()) ::
          [String.t()] | false
  defp bfs_path(graph, queue, parents, to_id) do
    case :queue.out(queue) do
      {:empty, _queue} ->
        false

      {{:value, vertex_id}, queue} ->
        neighbours = neighbour_ids(graph, vertex_id, :out)

        if to_id in neighbours do
          path_to(parents, vertex_id, [to_id])
        else
          new = Enum.reject(neighbours, &Map.has_key?(parents, &1))
          parents = Enum.reduce(new, parents, &Map.put(&2, &1, vertex_id))
          bfs_path(graph, Enum.reduce(new, queue, &:queue.in/2), parents, to_id)
        end
    end
  end

  @spec path_to(%{String.t() => String.t() | nil}, String.t() | nil, [String.t()]) ::
          [String.t()]
  defp path_to(_parents, nil, path), do: path

  defp path_to(parents, vertex_id, path),
    do: path_to(parents, parents[vertex_id], [vertex_id | path])

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
    graph
    |> tree_groups(vertex)
    |> Map.new(fn {label, children} -> {label, Enum.sort_by(children, &Vertex.name/1)} end)
  end

  @doc false
  # The vertex's children in the tree by edge label, in no particular order
  # (navigation_children/2 sorts them by name).
  @spec tree_groups(t(), Vertex.t()) :: %{:digraph.label() => [Vertex.t()]}
  def tree_groups(%__MODULE__{} = graph, vertex) do
    graph
    |> tree_child_edges(Vertex.id(vertex))
    |> Enum.flat_map(fn {label, child_id} ->
      case get_vertex(graph, child_id) do
        nil -> []
        child -> [{label, child}]
      end
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end

  @doc false
  # The labels the vertex's children in the tree hang off it by.
  @spec tree_labels(t(), Vertex.t()) :: [:digraph.label()]
  def tree_labels(%__MODULE__{} = graph, vertex) do
    graph |> tree_child_edges(Vertex.id(vertex)) |> Enum.map(&elem(&1, 0)) |> Enum.uniq()
  end

  @spec tree_child_edges(t(), String.t()) :: [{:digraph.label(), String.t()}]
  defp tree_child_edges(graph, vertex_id) do
    if in_view?(graph, vertex_id) do
      for edge_id <- :digraph.out_edges(graph.tree_graph, vertex_id),
          {_edge_id, _vertex_id, child_id, label} <- [:digraph.edge(graph.tree_graph, edge_id)],
          in_view?(graph, child_id),
          do: {label, child_id}
    else
      []
    end
  end

  @doc false
  # The ids of the vertex's children in the tree, in no particular order.
  @spec tree_child_ids(t(), String.t()) :: [String.t()]
  def tree_child_ids(%__MODULE__{} = graph, vertex_id) do
    if in_view?(graph, vertex_id) do
      for child_id <- :digraph.out_neighbours(graph.tree_graph, vertex_id),
          in_view?(graph, child_id),
          do: child_id
    else
      []
    end
  end

  @doc false
  # Which graph this is (a view is of the graph it was made from).
  @spec identity(t()) :: :ets.tid()
  def identity(%__MODULE__{} = graph), do: graph.update_count

  @doc false
  # What a graph shows: changing when the graph does, or for a view, when it
  # sees other vertices.
  @spec version(t()) :: {pos_integer(), non_neg_integer() | nil}
  def version(%__MODULE__{view: nil} = graph), do: {get_update_count(graph), nil}

  def version(%__MODULE__{view: view} = graph),
    do: {get_update_count(graph), :erlang.phash2(view)}

  @doc """
  Creates a filtered subgraph using a composable filter.
  Returns a new Clarity.Graph instance with the filtered vertices and edges.

  The subgraph is a view: it shares the graph it was made from, and sees its
  vertices that pass the filter and the edges between them, rather than copying
  them. It is read-only. `delete/1` releases it, though it holds nothing of its
  own.

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

    %{graph | view: graph |> vertex_ids(query) |> MapSet.new(), subgraph: true, owner: self()}
  end

  @doc """
  Returns the whole graph that a view filters, or the graph itself when it is
  not a view. The result can read the graph, but not delete or change it.
  """
  @spec unfiltered(t()) :: t()
  def unfiltered(%__MODULE__{} = graph), do: %{graph | view: nil, owner: nil}

  @doc """
  Persists a graph to disk.

  The graph must not be a subgraph.

  Returns `{:error, posix}` on file errors (e.g., `:enoent`, `:eacces`, `:enospc`).
  """
  @spec persist(t(), Path.t()) :: result()
  def persist(%__MODULE__{subgraph: true}, _path), do: {:error, :subgraphs_are_readonly}

  # path is an internal persistence dir from a trusted caller; appended segments are hardcoded.
  # sobelow_skip ["Traversal"]
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
