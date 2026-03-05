# credo:disable-for-this-file Credo.Check.Refactor.Nesting
defmodule Clarity.Graph.Backend.Digraph.Traversal do
  @moduledoc false

  @spec vertices_within_steps(
          original_graph :: :digraph.graph(),
          root_vertex :: :digraph.vertex(),
          max_outgoing_steps :: non_neg_integer(),
          max_incoming_steps :: non_neg_integer()
        ) :: MapSet.t(:digraph.vertex())
  def vertices_within_steps(original_graph, root_vertex, max_outgoing_steps, max_incoming_steps)
      when max_outgoing_steps >= 0 and max_incoming_steps >= 0 do
    visited_vertices =
      bfs_direction(
        original_graph,
        MapSet.new([root_vertex]),
        root_vertex,
        max_outgoing_steps,
        &:digraph.out_neighbours/2
      )

    bfs_direction(
      original_graph,
      visited_vertices,
      root_vertex,
      max_incoming_steps,
      &:digraph.in_neighbours/2
    )
  end

  @spec bfs_direction(
          original_graph :: :digraph.graph(),
          visited :: MapSet.t(:digraph.vertex()),
          start_vertex :: :digraph.vertex(),
          max_steps :: non_neg_integer(),
          neighbours_fun :: (:digraph.graph(), :digraph.vertex() -> [:digraph.vertex()])
        ) :: MapSet.t(:digraph.vertex())
  defp bfs_direction(_original_graph, visited, _start_vertex, 0, _), do: visited

  defp bfs_direction(original_graph, visited, start_vertex, max_steps, neighbours_fun) do
    queue = :queue.in({start_vertex, 0}, :queue.new())
    bfs_loop(queue, original_graph, visited, max_steps, neighbours_fun)
  end

  @spec bfs_loop(
          queue :: :queue.queue(),
          original_graph :: :digraph.graph(),
          visited :: MapSet.t(:digraph.vertex()),
          max_steps :: non_neg_integer(),
          neighbours_fun :: (:digraph.graph(), :digraph.vertex() -> [:digraph.vertex()])
        ) :: MapSet.t(:digraph.vertex())
  defp bfs_loop(queue, original_graph, visited, max_steps, neighbours_fun) do
    case :queue.out(queue) do
      {:empty, _} ->
        visited

      {{:value, {current_vertex, current_depth}}, queue_tail} ->
        {updated_queue, updated_visited} =
          if current_depth < max_steps do
            expand(
              current_vertex,
              current_depth,
              original_graph,
              visited,
              queue_tail,
              neighbours_fun
            )
          else
            {queue_tail, visited}
          end

        bfs_loop(
          updated_queue,
          original_graph,
          updated_visited,
          max_steps,
          neighbours_fun
        )
    end
  end

  @spec expand(
          vertex :: :digraph.vertex(),
          depth :: non_neg_integer(),
          original_graph :: :digraph.graph(),
          visited :: MapSet.t(:digraph.vertex()),
          queue :: :queue.queue(),
          neighbours_fun :: (:digraph.graph(), :digraph.vertex() -> [:digraph.vertex()])
        ) :: {:queue.queue(), MapSet.t(:digraph.vertex())}
  defp expand(vertex, depth, original_graph, visited, queue, neighbours_fun) do
    neighbours = neighbours_fun.(original_graph, vertex)

    Enum.reduce(neighbours, {queue, visited}, fn neighbour, {q_acc, s_acc} ->
      if MapSet.member?(s_acc, neighbour) do
        {q_acc, s_acc}
      else
        {:queue.in({neighbour, depth + 1}, q_acc), MapSet.put(s_acc, neighbour)}
      end
    end)
  end
end
