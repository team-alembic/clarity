defmodule Clarity.Graph.Backend.CypherRemote.Mutations do
  @moduledoc false

  alias Clarity.Graph.Backend.Cypher
  alias Clarity.Graph.Backend.WriteBuffer

  @spec add_vertex(struct(), String.t(), module(), struct(), String.t(), module(), pos_integer()) ::
          struct()
  def add_vertex(state, vertex_id, vertex_type, vertex_struct, caused_by_id, adapter, batch_size) do
    props = Cypher.serialize_vertex(vertex_id, vertex_type, vertex_struct)

    statements = [
      adapter.statement("MERGE (v:Vertex {id: $id}) SET v = $props", %{
        "id" => vertex_id,
        "props" => props
      }),
      adapter.statement(
        "MATCH (a:Vertex {id: $from_id}), (b:Vertex {id: $to_id}) MERGE (a)-[:CAUSED_BY]->(b)",
        %{"from_id" => caused_by_id, "to_id" => vertex_id}
      )
    ]

    state
    |> enqueue(statements, adapter, batch_size)
    |> bump_update_count()
  end

  @spec add_edge(struct(), String.t(), String.t(), term(), module(), pos_integer()) :: struct()
  def add_edge(state, from_id, to_id, label, adapter, batch_size) do
    statement =
      adapter.statement(
        """
        MATCH (a:Vertex {id: $from_id}), (b:Vertex {id: $to_id})
        MERGE (a)-[r:EDGE {label: $label}]->(b)
        MERGE (a)-[t:TREE_EDGE {label: $label}]->(b)
        """,
        %{"from_id" => from_id, "to_id" => to_id, "label" => Cypher.serialize_field_value(label)}
      )

    state
    |> enqueue([statement], adapter, batch_size)
    |> bump_update_count()
  end

  @spec purge(struct(), String.t(), module()) :: {[struct()], struct()}
  def purge(state, vertex_id, adapter) do
    state = flush(state, adapter)

    rows =
      adapter.run_query(
        state,
        """
        MATCH (start:Vertex {id: $id})-[:CAUSED_BY*0..]->(n:Vertex)
        WITH n, n {.*} AS props
        DETACH DELETE n
        RETURN props
        """,
        %{"id" => vertex_id}
      )

    purged = Enum.map(rows, fn [props] -> Cypher.deserialize_vertex(props) end)
    {purged, bump_update_count(state)}
  end

  @spec enqueue(struct(), [term()], module(), pos_integer()) :: struct()
  defp enqueue(state, statements, adapter, batch_size) do
    WriteBuffer.enqueue(state, statements, batch_size, &adapter.run_batch/2)
  end

  @spec flush(struct(), module()) :: struct()
  defp flush(state, adapter) do
    WriteBuffer.flush(state, &adapter.run_batch/2)
  end

  @spec bump_update_count(struct()) :: struct()
  defp bump_update_count(state), do: %{state | update_count: state.update_count + 1}
end
