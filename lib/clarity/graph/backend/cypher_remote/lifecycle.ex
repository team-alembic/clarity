defmodule Clarity.Graph.Backend.CypherRemote.Lifecycle do
  @moduledoc false

  @spec delete(struct(), boolean(), module()) :: :ok
  def delete(_state, true, _adapter), do: :ok

  def delete(state, false, adapter) do
    adapter.run_query(state, "MATCH (n:Vertex) DETACH DELETE n", %{})
    :ok
  end

  @spec clear(struct(), module()) :: struct()
  def clear(state, adapter) do
    adapter.run_query(state, "MATCH (n:Vertex) DETACH DELETE n", %{})
    %{state | update_count: state.update_count + 1, write_buffer: []}
  end

  @spec handover(struct(), pid(), boolean()) :: struct()
  def handover(state, _pid, _subgraph), do: state

  @spec get_update_count(struct()) :: non_neg_integer()
  def get_update_count(state), do: state.update_count

  @spec create_subgraph(struct(), [String.t()]) :: struct()
  def create_subgraph(state, vertex_ids) do
    %{state | subgraph_ids: MapSet.new(vertex_ids)}
  end
end
