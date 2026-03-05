defmodule Clarity.Graph.Backend.Digraph do
  @moduledoc """
  Graph backend using Erlang's `:digraph` and ETS tables.

  This is the default backend for Clarity. It stores graph data entirely
  in-process using three `:digraph` instances (main, tree, provenance) and
  three ETS tables (vertices, update_count, indexes).
  """

  @behaviour Clarity.Graph.Backend

  alias Clarity.Graph.Backend
  alias Clarity.Graph.Backend.Digraph.Traversal
  alias Clarity.Graph.Backend.Digraph.Tree

  defstruct [
    :main_graph,
    :tree_graph,
    :provenance_graph,
    :vertices,
    :update_count,
    :indexes
  ]

  @type t :: %__MODULE__{
          main_graph: :digraph.graph(),
          tree_graph: :digraph.graph(),
          provenance_graph: :digraph.graph(),
          vertices: :ets.tid(),
          update_count: :ets.tid(),
          indexes: :ets.tid()
        }

  @impl Backend
  def new(_opts \\ []) do
    main_graph = :digraph.new()
    tree_graph = :digraph.new([:acyclic])
    provenance_graph = :digraph.new([:acyclic])
    vertices = :ets.new(Clarity.Vertex, [:set, :protected, read_concurrency: true])
    update_count = :ets.new(:update_count, [:set, :protected, read_concurrency: true])
    indexes = :ets.new(:indexes, [:set, :protected, read_concurrency: true])

    :ets.insert(update_count, {:count, 0})

    %__MODULE__{
      main_graph: main_graph,
      tree_graph: tree_graph,
      provenance_graph: provenance_graph,
      vertices: vertices,
      update_count: update_count,
      indexes: indexes
    }
  end

  @impl Backend
  def delete(state, subgraph) do
    :digraph.delete(state.main_graph)
    :digraph.delete(state.tree_graph)

    if !subgraph do
      :digraph.delete(state.provenance_graph)
      :ets.delete(state.vertices)
      :ets.delete(state.update_count)
      :ets.delete(state.indexes)
    end

    :ok
  end

  @impl Backend
  def clear(state) do
    :digraph.del_vertices(state.main_graph, :digraph.vertices(state.main_graph))
    :digraph.del_vertices(state.tree_graph, :digraph.vertices(state.tree_graph))
    :digraph.del_vertices(state.provenance_graph, :digraph.vertices(state.provenance_graph))

    :ets.delete_all_objects(state.vertices)
    :ets.delete_all_objects(state.indexes)

    increment_update_count(state)

    state
  end

  @impl Backend
  def handover(state, pid, subgraph) do
    if subgraph do
      handover_subgraph(state, pid)
    else
      handover_main(state, pid)
    end

    state
  end

  @impl Backend
  def add_vertex(state, vertex_id, vertex_type, vertex_struct, caused_by_id) do
    :ets.insert(state.vertices, {vertex_id, vertex_type, vertex_struct})

    :digraph.add_vertex(state.main_graph, vertex_id)
    Tree.add_vertex(state.tree_graph, vertex_id)
    :digraph.add_vertex(state.provenance_graph, vertex_id)

    :digraph.add_edge(state.provenance_graph, caused_by_id, vertex_id)

    increment_update_count(state)

    state
  end

  @impl Backend
  def add_edge(state, from_id, to_id, label) do
    :digraph.add_edge(state.main_graph, from_id, to_id, label)
    Tree.add_edge(state.tree_graph, from_id, to_id, label)

    update_degree_index(state, from_id, label, :out_degree, 1)
    update_degree_index(state, to_id, label, :in_degree, 1)

    increment_update_count(state)

    state
  end

  @impl Backend
  def purge(state, vertex_id) do
    reachable_ids = :digraph_utils.reachable([vertex_id], state.provenance_graph)

    purged_vertices =
      reachable_ids
      |> Enum.map(fn id ->
        case :ets.lookup(state.vertices, id) do
          [{^id, _type, vertex_struct}] -> vertex_struct
          [] -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    Enum.each(reachable_ids, fn id ->
      purge_vertex_indexes(state, id)
      :ets.delete(state.vertices, id)
      :digraph.del_vertex(state.main_graph, id)
      :digraph.del_vertex(state.tree_graph, id)
      :digraph.del_vertex(state.provenance_graph, id)
    end)

    increment_update_count(state)

    {purged_vertices, state}
  end

  @impl Backend
  def get_vertex(state, vertex_id) do
    :ets.lookup_element(state.vertices, vertex_id, 3, nil)
  end

  @impl Backend
  def vertex_count(state) do
    :digraph.no_vertices(state.main_graph)
  end

  @impl Backend
  def get_update_count(state) do
    :ets.lookup_element(state.update_count, :count, 2)
  end

  @impl Backend
  def out_neighbors(state, vertex_id) do
    state.main_graph
    |> :digraph.out_neighbours(vertex_id)
    |> Enum.map(&get_vertex(state, &1))
  end

  @impl Backend
  def in_neighbors(state, vertex_id) do
    state.main_graph
    |> :digraph.in_neighbours(vertex_id)
    |> Enum.map(&get_vertex(state, &1))
  end

  @impl Backend
  def out_edges(state, vertex_id) do
    :digraph.out_edges(state.main_graph, vertex_id)
  end

  @impl Backend
  def in_edges(state, vertex_id) do
    :digraph.in_edges(state.main_graph, vertex_id)
  end

  @impl Backend
  def edges(state) do
    :digraph.edges(state.main_graph)
  end

  @impl Backend
  def edge(state, edge_id) do
    case :digraph.edge(state.main_graph, edge_id) do
      {edge_id, from_id, to_id, label} ->
        from_vertex = get_vertex(state, from_id)
        to_vertex = get_vertex(state, to_id)
        {edge_id, from_vertex, to_vertex, label}

      false ->
        false
    end
  end

  @impl Backend
  def in_degree(state, vertex_id) do
    state.main_graph
    |> :digraph.in_edges(vertex_id)
    |> length()
  end

  @impl Backend
  def in_degree(state, vertex_id, label) do
    key = {vertex_id, label, :in_degree}
    :ets.lookup_element(state.indexes, key, 2, 0)
  end

  @impl Backend
  def out_degree(state, vertex_id) do
    state.main_graph
    |> :digraph.out_edges(vertex_id)
    |> length()
  end

  @impl Backend
  def out_degree(state, vertex_id, label) do
    key = {vertex_id, label, :out_degree}
    :ets.lookup_element(state.indexes, key, 2, 0)
  end

  @impl Backend
  def vertices(state, query) do
    all_vertices = state.main_graph |> :digraph.vertices() |> MapSet.new()

    state.vertices
    |> :ets.select(vertex_query_to_ets_match_spec(query, :"$3"))
    |> Enum.filter(&MapSet.member?(all_vertices, Clarity.Vertex.id(&1)))
  end

  @impl Backend
  def vertex_ids(state, query) do
    all_vertices = state.main_graph |> :digraph.vertices() |> MapSet.new()

    state.vertices
    |> :ets.select(vertex_query_to_ets_match_spec(query, :"$1"))
    |> MapSet.new()
    |> MapSet.intersection(all_vertices)
    |> MapSet.to_list()
  end

  @impl Backend
  def available_vertex_types(state) do
    state.main_graph
    |> :digraph.vertices()
    |> Enum.map(&:ets.lookup_element(state.vertices, &1, 2))
    |> Enum.uniq()
    |> Enum.sort()
  end

  @impl Backend
  def breadcrumbs(state, vertex_id) do
    case :digraph.get_short_path(state.tree_graph, "root", vertex_id) do
      false -> false
      path_ids -> Enum.map(path_ids, &get_vertex(state, &1))
    end
  end

  @impl Backend
  def get_short_path(state, from_id, to_id) do
    case :digraph.get_short_path(state.main_graph, from_id, to_id) do
      false -> false
      path_ids -> Enum.map(path_ids, &get_vertex(state, &1))
    end
  end

  @impl Backend
  def navigation_children(state, vertex_id) do
    state.tree_graph
    |> :digraph.out_edges(vertex_id)
    |> Enum.map(fn edge_id ->
      {_, _, to_vertex_id, label} = :digraph.edge(state.tree_graph, edge_id)
      {label, to_vertex_id}
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Map.new(fn {label, v_ids} ->
      children =
        v_ids
        |> Enum.map(&get_vertex(state, &1))
        |> Enum.sort_by(&Clarity.Vertex.name/1)

      {label, children}
    end)
  end

  @impl Backend
  def vertices_within_steps(state, vertex_id, max_out, max_in) do
    Traversal.vertices_within_steps(state.main_graph, vertex_id, max_out, max_in)
  end

  @impl Backend
  def reachable_from(state, source_vertex_ids) do
    source_set = MapSet.new(source_vertex_ids)

    for vertex_id <- :digraph.vertices(state.main_graph),
        MapSet.member?(source_set, vertex_id) or
          Enum.any?(source_vertex_ids, fn source_id ->
            :digraph.get_path(state.main_graph, source_id, vertex_id) != false
          end) do
      vertex_id
    end
  end

  @impl Backend
  def create_subgraph(state, vertex_ids) do
    filtered_main_graph = :digraph_utils.subgraph(state.main_graph, vertex_ids)
    filtered_tree_graph = :digraph_utils.subgraph(state.tree_graph, vertex_ids)

    %__MODULE__{
      main_graph: filtered_main_graph,
      tree_graph: filtered_tree_graph,
      provenance_graph: state.provenance_graph,
      vertices: state.vertices,
      update_count: state.update_count,
      indexes: state.indexes
    }
  end

  @impl Backend
  def persist(state, path) do
    with :ok <- File.mkdir_p(path),
         :ok <- persist_ets_table(state.vertices, Path.join(path, "vertices.ets")),
         :ok <- persist_ets_table(state.update_count, Path.join(path, "update_count.ets")),
         :ok <- persist_ets_table(state.indexes, Path.join(path, "indexes.ets")),
         :ok <- persist_digraph(state.main_graph, path, "main"),
         :ok <- persist_digraph(state.tree_graph, path, "tree") do
      persist_digraph(state.provenance_graph, path, "provenance")
    end
  end

  @impl Backend
  def load(path, _opts \\ []) do
    with {:ok, vertices_tab} <- load_ets_table(Path.join(path, "vertices.ets")),
         {:ok, update_count_tab} <- load_ets_table(Path.join(path, "update_count.ets")),
         {:ok, indexes_tab} <- load_ets_table(Path.join(path, "indexes.ets")),
         {:ok, main_graph} <- load_digraph(path, "main", true),
         {:ok, tree_graph} <- load_digraph(path, "tree", false),
         {:ok, provenance_graph} <- load_digraph(path, "provenance", false) do
      state = %__MODULE__{
        main_graph: main_graph,
        tree_graph: tree_graph,
        provenance_graph: provenance_graph,
        vertices: vertices_tab,
        update_count: update_count_tab,
        indexes: indexes_tab
      }

      {:ok, state}
    end
  end

  # ETS match spec generation

  @spec vertex_query_to_ets_match_spec(Clarity.Graph.query(), atom()) :: :ets.match_spec()
  defp vertex_query_to_ets_match_spec(true, select), do: [{{:"$1", :"$2", :"$3"}, [], [select]}]

  defp vertex_query_to_ets_match_spec(query, select) do
    condition = query_to_match_condition(query)
    [{{:"$1", :"$2", :"$3"}, [condition], [select]}]
  end

  @spec query_to_match_condition(Clarity.Graph.query()) :: term()
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

  @spec query_subject(Clarity.Graph.query_subject()) :: term()
  defp query_subject(:vertex_type), do: :"$2"
  defp query_subject(:vertex_id), do: :"$1"
  defp query_subject({:field, field}), do: {:map_get, field, :"$3"}

  # Degree index helpers

  @spec update_degree_index(t(), String.t(), term(), :in_degree | :out_degree, integer()) :: :ok
  defp update_degree_index(state, vertex_id, label, direction, delta) do
    key = {vertex_id, label, direction}
    :ets.update_counter(state.indexes, key, delta, {key, 0})
    :ok
  end

  @spec purge_vertex_indexes(t(), String.t()) :: :ok
  defp purge_vertex_indexes(state, vertex_id) do
    for edge_id <- :digraph.out_edges(state.main_graph, vertex_id) do
      {^edge_id, ^vertex_id, to_id, label} = :digraph.edge(state.main_graph, edge_id)
      update_degree_index(state, to_id, label, :in_degree, -1)
    end

    for edge_id <- :digraph.in_edges(state.main_graph, vertex_id) do
      {^edge_id, from_id, ^vertex_id, label} = :digraph.edge(state.main_graph, edge_id)
      update_degree_index(state, from_id, label, :out_degree, -1)
    end

    :ets.match_delete(state.indexes, {{vertex_id, :_, :_}, :_})

    :ok
  end

  @spec increment_update_count(t()) :: pos_integer()
  defp increment_update_count(state) do
    :ets.update_counter(state.update_count, :count, 1, {:count, 0})
  end

  # Handover helpers

  defp handover_subgraph(state, pid) do
    {vtab1, etab1, ntab1, _} = unpack_digraph(state.main_graph)
    :ets.give_away(vtab1, pid, :graph_handover)
    :ets.give_away(etab1, pid, :graph_handover)
    :ets.give_away(ntab1, pid, :graph_handover)

    {vtab2, etab2, ntab2, _} = unpack_digraph(state.tree_graph)
    :ets.give_away(vtab2, pid, :graph_handover)
    :ets.give_away(etab2, pid, :graph_handover)
    :ets.give_away(ntab2, pid, :graph_handover)
  end

  defp handover_main(state, pid) do
    :ets.give_away(state.vertices, pid, :graph_handover)
    :ets.give_away(state.update_count, pid, :graph_handover)
    :ets.give_away(state.indexes, pid, :graph_handover)

    {vtab1, etab1, ntab1, _} = unpack_digraph(state.main_graph)
    :ets.give_away(vtab1, pid, :graph_handover)
    :ets.give_away(etab1, pid, :graph_handover)
    :ets.give_away(ntab1, pid, :graph_handover)

    {vtab2, etab2, ntab2, _} = unpack_digraph(state.tree_graph)
    :ets.give_away(vtab2, pid, :graph_handover)
    :ets.give_away(etab2, pid, :graph_handover)
    :ets.give_away(ntab2, pid, :graph_handover)

    {vtab3, etab3, ntab3, _} = unpack_digraph(state.provenance_graph)
    :ets.give_away(vtab3, pid, :graph_handover)
    :ets.give_away(etab3, pid, :graph_handover)
    :ets.give_away(ntab3, pid, :graph_handover)
  end

  # Persistence helpers

  @spec persist_ets_table(:ets.tid(), Path.t()) :: :ok | {:error, :file.posix()}
  defp persist_ets_table(table, file_path) do
    case :ets.tab2file(table, String.to_charlist(file_path)) do
      :ok -> :ok
      {:error, {:file_error, _path, posix_error}} -> {:error, posix_error}
      {:error, reason} -> {:error, reason}
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
      {:ok, table} -> {:ok, table}
      {:error, {:read_error, {:file_error, _path, posix_error}}} -> {:error, posix_error}
      {:error, reason} -> {:error, reason}
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

  # Digraph internals

  @dialyzer {:nowarn_function, unpack_digraph: 1}
  @spec unpack_digraph(:digraph.graph()) :: {:ets.tid(), :ets.tid(), :ets.tid(), boolean()}
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
