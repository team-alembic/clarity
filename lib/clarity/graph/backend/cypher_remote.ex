defmodule Clarity.Graph.Backend.CypherRemote do
  @moduledoc false

  alias Clarity.Graph.Backend.CypherRemote.Lifecycle
  alias Clarity.Graph.Backend.CypherRemote.Mutations
  alias Clarity.Graph.Backend.CypherRemote.Persistence
  alias Clarity.Graph.Backend.CypherRemote.Queries

  defdelegate delete(state, subgraph, adapter), to: Lifecycle
  defdelegate clear(state, adapter), to: Lifecycle
  defdelegate handover(state, pid, subgraph), to: Lifecycle
  defdelegate get_update_count(state), to: Lifecycle
  defdelegate create_subgraph(state, vertex_ids), to: Lifecycle

  defdelegate add_vertex(
                state,
                vertex_id,
                vertex_type,
                vertex_struct,
                caused_by_id,
                adapter,
                batch_size
              ),
              to: Mutations

  defdelegate add_edge(state, from_id, to_id, label, adapter, batch_size), to: Mutations
  defdelegate purge(state, vertex_id, adapter), to: Mutations

  defdelegate get_vertex(state, vertex_id, adapter), to: Queries
  defdelegate vertex_count(state, adapter), to: Queries
  defdelegate out_neighbors(state, vertex_id, adapter), to: Queries
  defdelegate in_neighbors(state, vertex_id, adapter), to: Queries
  defdelegate out_edges(state, vertex_id, adapter), to: Queries
  defdelegate in_edges(state, vertex_id, adapter), to: Queries
  defdelegate edges(state, adapter), to: Queries
  defdelegate edge(state, edge_id, adapter), to: Queries
  defdelegate in_degree(state, vertex_id, adapter), to: Queries
  defdelegate in_degree(state, vertex_id, label, adapter), to: Queries
  defdelegate out_degree(state, vertex_id, adapter), to: Queries
  defdelegate out_degree(state, vertex_id, label, adapter), to: Queries
  defdelegate vertices(state, query, adapter), to: Queries
  defdelegate vertex_ids(state, query, adapter), to: Queries
  defdelegate available_vertex_types(state, adapter), to: Queries
  defdelegate breadcrumbs(state, vertex_id, adapter), to: Queries
  defdelegate get_short_path(state, from_id, to_id, adapter), to: Queries
  defdelegate navigation_children(state, vertex_id, adapter), to: Queries
  defdelegate vertices_within_steps(state, vertex_id, max_out, max_in, adapter), to: Queries
  defdelegate reachable_from(state, source_vertex_ids, adapter), to: Queries

  defdelegate persist(state, path, file_name, adapter), to: Persistence
end
