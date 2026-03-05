defmodule Clarity.Graph.Backend do
  @moduledoc """
  Behaviour for graph storage backends.

  Each backend implements the full graph-semantic API, allowing backends like
  Neo4j to use native capabilities (e.g. Cypher shortest paths) rather than
  emulating low-level storage primitives.

  The default backend is `Clarity.Graph.Backend.Digraph`, which uses Erlang's
  `:digraph` and ETS tables for in-process graph storage.
  """

  @type state :: term()
  @type vertex_id :: String.t()
  @type vertex_type :: module()
  @type vertex_struct :: struct()
  @type edge_id :: term()
  @type label :: term()
  @type query :: Clarity.Graph.query()

  # Lifecycle

  @callback new(opts :: keyword()) :: state
  @callback delete(state, subgraph :: boolean()) :: :ok
  @callback clear(state) :: state
  @callback handover(state, pid(), subgraph :: boolean()) :: state

  # Writes

  @callback add_vertex(state, vertex_id, vertex_type, vertex_struct, caused_by_id :: vertex_id) ::
              state
  @callback add_edge(state, from_id :: vertex_id, to_id :: vertex_id, label) :: state
  @callback purge(state, vertex_id) :: {[vertex_struct], state}

  # Single reads

  @callback get_vertex(state, vertex_id) :: vertex_struct | nil
  @callback vertex_count(state) :: non_neg_integer()
  @callback get_update_count(state) :: non_neg_integer()

  # Neighbor/edge reads

  @callback out_neighbors(state, vertex_id) :: [vertex_struct]
  @callback in_neighbors(state, vertex_id) :: [vertex_struct]
  @callback out_edges(state, vertex_id) :: [edge_id]
  @callback in_edges(state, vertex_id) :: [edge_id]
  @callback edges(state) :: [edge_id]
  @callback edge(state, edge_id) ::
              {edge_id, vertex_struct | nil, vertex_struct | nil, label} | false
  @callback in_degree(state, vertex_id) :: non_neg_integer()
  @callback in_degree(state, vertex_id, label) :: non_neg_integer()
  @callback out_degree(state, vertex_id) :: non_neg_integer()
  @callback out_degree(state, vertex_id, label) :: non_neg_integer()

  # Query

  @callback vertices(state, query) :: [vertex_struct]
  @callback vertex_ids(state, query) :: [vertex_id]
  @callback available_vertex_types(state) :: [module()]

  # Navigation

  @callback breadcrumbs(state, vertex_id) :: [vertex_struct] | false
  @callback get_short_path(state, from_id :: vertex_id, to_id :: vertex_id) ::
              [vertex_struct] | false
  @callback navigation_children(state, vertex_id) :: %{label => [vertex_struct]}

  # Traversal

  @callback vertices_within_steps(
              state,
              vertex_id,
              max_out :: non_neg_integer(),
              max_in :: non_neg_integer()
            ) :: MapSet.t()
  @callback reachable_from(state, [vertex_id]) :: [vertex_id]

  # Subgraph

  @callback create_subgraph(state, [vertex_id]) :: state

  # Persistence

  @callback persist(state, Path.t()) :: :ok | {:error, term()}
  @callback load(Path.t(), opts :: keyword()) :: {:ok, state} | {:error, term()}

  @doc "Returns the configured graph backend module."
  @spec configured_backend() :: module()
  def configured_backend do
    Application.get_env(:clarity, :graph_backend, Clarity.Graph.Backend.Digraph)
  end
end
