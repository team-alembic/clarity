defmodule Clarity.Graph.Traversal do
  @moduledoc false

  alias Clarity.Graph
  alias Clarity.Vertex

  @spec vertices_within_steps(Graph.t(), Vertex.t(), non_neg_integer(), non_neg_integer()) ::
          MapSet.t(String.t())
  def vertices_within_steps(graph, center_vertex, max_outgoing_steps, max_incoming_steps) do
    center_id = Vertex.id(center_vertex)

    outgoing = bfs_ids(graph, center_vertex, max_outgoing_steps, &Graph.out_neighbors/2)
    incoming = bfs_ids(graph, center_vertex, max_incoming_steps, &Graph.in_neighbors/2)

    outgoing
    |> MapSet.union(incoming)
    |> MapSet.put(center_id)
  end

  @spec reachable_from(Graph.t(), [Vertex.t()]) :: [String.t()]
  def reachable_from(graph, source_vertices) do
    source_vertices
    |> Enum.reduce(MapSet.new(), fn source_vertex, acc ->
      reachable = bfs_ids(graph, source_vertex, :infinity, &Graph.out_neighbors/2)
      MapSet.union(acc, reachable)
    end)
    |> MapSet.to_list()
  end

  @spec bfs_ids(Graph.t(), Vertex.t(), non_neg_integer() | :infinity, (Graph.t(), Vertex.t() ->
                                                                         [Vertex.t()])) ::
          MapSet.t(String.t())
  defp bfs_ids(graph, start_vertex, max_depth, neighbors_fun) do
    queue = :queue.from_list([{start_vertex, 0}])
    visited = MapSet.new([Vertex.id(start_vertex)])

    bfs_loop(graph, queue, visited, max_depth, neighbors_fun)
  end

  @spec bfs_loop(
          Graph.t(),
          :queue.queue({Vertex.t(), non_neg_integer()}),
          MapSet.t(String.t()),
          non_neg_integer() | :infinity,
          (Graph.t(), Vertex.t() -> [Vertex.t()])
        ) :: MapSet.t(String.t())
  defp bfs_loop(graph, queue, visited, max_depth, neighbors_fun) do
    case :queue.out(queue) do
      {:empty, _} ->
        visited

      {{:value, {vertex, depth}}, queue_tail} ->
        if max_depth != :infinity and depth >= max_depth do
          bfs_loop(graph, queue_tail, visited, max_depth, neighbors_fun)
        else
          {next_queue, next_visited} =
            graph
            |> neighbors_fun.(vertex)
            |> Enum.reduce({queue_tail, visited}, fn neighbor, {q, v} ->
              neighbor_id = Vertex.id(neighbor)

              if MapSet.member?(v, neighbor_id) do
                {q, v}
              else
                {:queue.in({neighbor, depth + 1}, q), MapSet.put(v, neighbor_id)}
              end
            end)

          bfs_loop(graph, next_queue, next_visited, max_depth, neighbors_fun)
        end
    end
  end
end
