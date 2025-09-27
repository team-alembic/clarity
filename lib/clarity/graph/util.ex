# credo:disable-for-this-file Credo.Check.Refactor.Nesting
defmodule Clarity.Graph.Util do
  @moduledoc false

  @doc """
  Create and return a *new* digraph that contains every vertex reachable from
  `root_vertex` within **`max_outgoing_steps` forward hops** *or*
  **`max_incoming_steps` backward hops**, together with every edge that connects
  those vertices.

  The traversal is breadth‑first in each direction, so the overall complexity
  remains linear in the size of the resulting sub‑graph (`O(Vₛ + Eₛ)`).

  ## Parameters

    * `original_graph` – the `:digraph` you want to sample from.
    * `root_vertex` – where traversal starts.
    * `max_outgoing_steps` – how far to follow *outgoing* edges.
    * `max_incoming_steps` – how far to follow *incoming* edges.

  """
  @spec subgraph_within_steps(
          original_graph :: :digraph.graph(),
          root_vertex :: :digraph.vertex(),
          max_outgoing_steps :: non_neg_integer(),
          max_incoming_steps :: non_neg_integer()
        ) :: :digraph.graph()
  def subgraph_within_steps(original_graph, root_vertex, max_outgoing_steps, max_incoming_steps)
      when max_outgoing_steps >= 0 and max_incoming_steps >= 0 do
    subgraph = :digraph.new()
    copy_vertex(original_graph, subgraph, root_vertex)

    {subgraph, visited_vertices} =
      bfs_direction(
        original_graph,
        subgraph,
        MapSet.new([root_vertex]),
        root_vertex,
        max_outgoing_steps,
        &:digraph.out_edges/2
      )

    {_subgraph, _} =
      bfs_direction(
        original_graph,
        subgraph,
        visited_vertices,
        root_vertex,
        max_incoming_steps,
        &:digraph.in_edges/2
      )

    subgraph
  end

  @spec bfs_direction(original_graph, subgraph, visited, start_vertex, max_steps, edges_fun) ::
          {subgraph, visited}
        when original_graph: :digraph.graph(),
             subgraph: :digraph.graph(),
             visited: MapSet.t(:digraph.vertex()),
             start_vertex: :digraph.vertex(),
             max_steps: non_neg_integer(),
             edges_fun: (original_graph, :digraph.vertex() -> [:digraph.edge()])
  defp bfs_direction(_original_graph, subgraph, visited, _start_vertex, 0, _),
    do: {subgraph, visited}

  defp bfs_direction(original_graph, subgraph, visited, start_vertex, max_steps, edges_fun) do
    queue = :queue.in({start_vertex, 0}, :queue.new())
    bfs_loop(queue, original_graph, subgraph, visited, max_steps, edges_fun)
  end

  @spec bfs_loop(queue, original_graph, subgraph, visited, max_steps, edges_fun) ::
          {subgraph, visited}
        when queue: :queue.queue(),
             original_graph: :digraph.graph(),
             subgraph: :digraph.graph(),
             visited: MapSet.t(vertex),
             max_steps: non_neg_integer(),
             edges_fun: (original_graph, vertex -> [edge]),
             vertex: :digraph.vertex(),
             edge: :digraph.edge()
  defp bfs_loop(queue, original_graph, subgraph, visited, max_steps, edges_fun) do
    case :queue.out(queue) do
      {:empty, _} ->
        {subgraph, visited}

      {{:value, {current_vertex, current_depth}}, queue_tail} ->
        {updated_queue, updated_visited} =
          if current_depth < max_steps do
            expand(
              current_vertex,
              current_depth,
              original_graph,
              subgraph,
              visited,
              queue_tail,
              edges_fun
            )
          else
            {queue_tail, visited}
          end

        bfs_loop(
          updated_queue,
          original_graph,
          subgraph,
          updated_visited,
          max_steps,
          edges_fun
        )
    end
  end

  @spec expand(vertex, depth, original_graph, subgraph, visited, queue, edges_fun) ::
          {queue, visited}
        when vertex: :digraph.vertex(),
             depth: non_neg_integer(),
             original_graph: :digraph.graph(),
             subgraph: :digraph.graph(),
             visited: MapSet.t(:digraph.vertex()),
             queue: :queue.queue(),
             edges_fun: (original_graph, vertex -> [:digraph.edge()])
  defp expand(vertex, depth, original_graph, subgraph, visited, queue, edges_fun) do
    Enum.reduce(edges_fun.(original_graph, vertex), {queue, visited}, fn edge_id,
                                                                         {q_acc, s_acc} ->
      {_, from_vertex, to_vertex, edge_label} = :digraph.edge(original_graph, edge_id)
      adjacent_vertex = if vertex == from_vertex, do: to_vertex, else: from_vertex

      {updated_queue, updated_visited} =
        if MapSet.member?(s_acc, adjacent_vertex) do
          {q_acc, s_acc}
        else
          copy_vertex(original_graph, subgraph, adjacent_vertex)
          {:queue.in({adjacent_vertex, depth + 1}, q_acc), MapSet.put(s_acc, adjacent_vertex)}
        end

      add_edge_if_absent(subgraph, edge_id, from_vertex, to_vertex, edge_label)
      {updated_queue, updated_visited}
    end)
  end

  @spec copy_vertex(
          src_graph :: :digraph.graph(),
          dst_graph :: :digraph.graph(),
          vertex :: :digraph.vertex()
        ) :: :digraph.vertex()
  defp copy_vertex(src_graph, dst_graph, vertex) do
    case :digraph.vertex(src_graph, vertex) do
      {^vertex, label} -> :digraph.add_vertex(dst_graph, vertex, label)
      _ -> :digraph.add_vertex(dst_graph, vertex)
    end
  end

  @spec add_edge_if_absent(
          dst_graph :: :digraph.graph(),
          edge_id :: :digraph.edge(),
          from_vertex :: :digraph.vertex(),
          to_vertex :: :digraph.vertex(),
          edge_label :: :digraph.label()
        ) :: :ok
  defp add_edge_if_absent(dst_graph, edge_id, from_vertex, to_vertex, edge_label) do
    case :digraph.edge(dst_graph, edge_id) do
      false ->
        :digraph.add_edge(dst_graph, edge_id, from_vertex, to_vertex, edge_label)
        :ok

      _ ->
        :ok
    end
  end
end
