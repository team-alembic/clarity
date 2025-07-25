defmodule AshAtlas.GraphUtil do
  @moduledoc false

  @type tree_node() :: %{
          node: :digraph.vertex(),
          children: %{
            optional(:digraph.label()) => [tree_node()]
          }
        }

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
  def subgraph_within_steps(
        original_graph,
        root_vertex,
        max_outgoing_steps,
        max_incoming_steps
      )
      when max_outgoing_steps >= 0 and max_incoming_steps >= 0 do
    subgraph = :digraph.new()
    copy_vertex(original_graph, subgraph, root_vertex)

    {subgraph, visited} =
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
        visited,
        root_vertex,
        max_incoming_steps,
        &:digraph.in_edges/2
      )

    subgraph
  end

  @doc """
  Converts a directed graph into a tree structure starting from the given root vertex.

  Traverses the graph using a queue-based approach, collects tree information, and builds
  a tree representation rooted at `root_vertex`.

  ## Parameters

    - `graph`: The directed graph (`:digraph.graph()`) to convert.
    - `root_vertex`: The vertex (`:digraph.vertex()`) to use as the root of the tree.

  ## Returns

    - A tree structure (`tree_node()`) representing the hierarchy of the graph starting from the root vertex.

  """
  @spec graph_to_tree(graph :: :digraph.graph(), root_vertex :: :digraph.vertex()) :: tree_node()
  def graph_to_tree(graph, root_vertex) do
    root_stub = %{node: root_vertex, children: %{}}

    visited = %{root_vertex => root_stub}
    queue = :queue.in(root_vertex, :queue.new())

    collected = collect_tree_info(graph, queue, visited)

    build_tree(collected, root_vertex)
  end

  defp collect_tree_info(graph, queue, visited) do
    case :queue.out(queue) do
      {:empty, _} ->
        visited

      {{:value, current_vertex}, queue_tail} ->
        {visited2, queue2} =
          Enum.reduce(
            :digraph.out_edges(graph, current_vertex),
            {visited, queue_tail},
            fn edge_id, {vis_acc, q_acc} ->
              {_, src, dst, edge_label} = :digraph.edge(graph, edge_id)
              child_vertex = if current_vertex == src, do: dst, else: src

              if Map.has_key?(vis_acc, child_vertex) do
                # Already placed elsewhere (shorter or equal path) → skip
                {vis_acc, q_acc}
              else
                child_stub = %{vertex: child_vertex, children: %{}}
                vis_with_child = Map.put(vis_acc, child_vertex, child_stub)

                parent = Map.fetch!(vis_with_child, current_vertex)

                updated_parent =
                  Map.update(
                    parent,
                    :children,
                    %{edge_label => [child_vertex]},
                    fn child_map ->
                      Map.update(child_map, edge_label, [child_vertex], &[child_vertex | &1])
                    end
                  )

                vis_parent_fixed = Map.put(vis_with_child, current_vertex, updated_parent)
                {vis_parent_fixed, :queue.in(child_vertex, q_acc)}
              end
            end
          )

        collect_tree_info(graph, queue2, visited2)
    end
  end

  defp build_tree(visited_map, vertex_id) do
    %{children: raw} = Map.fetch!(visited_map, vertex_id)

    concrete_children =
      Enum.into(raw, %{}, fn {label, id_list} ->
        {label, Enum.map(id_list, &build_tree(visited_map, &1))}
      end)

    %{node: vertex_id, children: concrete_children}
  end

  defp bfs_direction(_g, sub, seen, _start, 0, _), do: {sub, seen}

  defp bfs_direction(g, sub, seen, start, max_steps, edges_fun) do
    queue = :queue.in({start, 0}, :queue.new())
    bfs_loop(queue, g, sub, seen, max_steps, edges_fun)
  end

  defp bfs_loop(queue, g, sub, seen, max_steps, edges_fun) do
    case :queue.out(queue) do
      {:empty, _} ->
        {sub, seen}

      {{:value, {v, d}}, q1} ->
        {q2, seen2} =
          if d < max_steps do
            expand(v, d, g, sub, seen, q1, edges_fun)
          else
            {q1, seen}
          end

        bfs_loop(q2, g, sub, seen2, max_steps, edges_fun)
    end
  end

  defp expand(v, depth, g, sub, seen, queue, edges_fun) do
    Enum.reduce(edges_fun.(g, v), {queue, seen}, fn edge_id, {q_acc, s_acc} ->
      {_, from, to, label} = :digraph.edge(g, edge_id)
      other = if v == from, do: to, else: from

      {q2, s2} =
        if MapSet.member?(s_acc, other) do
          {q_acc, s_acc}
        else
          copy_vertex(g, sub, other)
          {:queue.in({other, depth + 1}, q_acc), MapSet.put(s_acc, other)}
        end

      add_edge_if_absent(sub, edge_id, from, to, label)
      {q2, s2}
    end)
  end

  defp copy_vertex(src, dst, v) do
    case :digraph.vertex(src, v) do
      {^v, lbl} -> :digraph.add_vertex(dst, v, lbl)
      _ -> :digraph.add_vertex(dst, v)
    end
  end

  defp add_edge_if_absent(dst, id, from, to, lbl) do
    case :digraph.edge(dst, id) do
      false -> :digraph.add_edge(dst, id, from, to, lbl)
      _ -> :ok
    end
  end
end
