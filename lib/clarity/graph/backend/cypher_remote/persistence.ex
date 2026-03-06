defmodule Clarity.Graph.Backend.CypherRemote.Persistence do
  @moduledoc false

  alias Clarity.Graph.Backend.WriteBuffer

  @spec persist(struct(), Path.t(), String.t(), module()) :: :ok | {:error, term()}
  def persist(state, path, file_name, adapter) do
    state = flush(state, adapter)

    rows =
      adapter.run_query(
        state,
        """
        MATCH (v:Vertex)
        OPTIONAL MATCH (v)-[r]->(v2:Vertex)
        RETURN collect(DISTINCT v {.*}) AS vertices,
               collect(DISTINCT {from: startNode(r).id, to: endNode(r).id, type: type(r), label: r.label}) AS edges
        """,
        %{}
      )

    case rows do
      [[vertices, raw_edges]] ->
        data = %{vertices: vertices, edges: raw_edges, update_count: state.update_count}
        binary = :erlang.term_to_binary(data)

        with :ok <- File.mkdir_p(path) do
          File.write(Path.join(path, file_name), binary)
        end

      [] ->
        :ok
    end
  end

  @spec flush(struct(), module()) :: struct()
  defp flush(state, adapter) do
    WriteBuffer.flush(state, &adapter.run_batch/2)
  end
end
