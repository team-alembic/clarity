# credo:disable-for-this-file Credo.Check.Refactor.Nesting
defmodule Clarity.GraphUtil do
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

  @doc """
  Converts a directed graph into a tree structure starting from the given root vertex.

  Traverses the graph using a queue-based approach, collects tree information, and builds
  a tree representation rooted at `root_vertex`.

  ## Parameters

    - `graph`: The directed graph (`:digraph.graph()`) to convert.
    - `root_vertex`: The vertex (`:digraph.vertex()`) to use as the root of the tree.

  ## Returns

    - A tree structure (`Clarity.tree()`) representing the hierarchy of the graph starting from the root vertex.

  """
  @spec graph_to_tree(graph :: :digraph.graph(), root_vertex :: :digraph.vertex()) ::
          Clarity.tree()
  def graph_to_tree(graph, root_vertex) do
    root_stub = %{node: root_vertex, children: %{}}

    visited_map = %{root_vertex => root_stub}
    queue = :queue.in(root_vertex, :queue.new())

    collected_tree_info = collect_tree_info(graph, queue, visited_map)

    build_tree(collected_tree_info, root_vertex)
  end

  @spec collect_tree_info(
          graph :: :digraph.graph(),
          queue :: :queue.queue(),
          visited_map :: %{required(:digraph.vertex()) => Clarity.tree()}
        ) :: %{required(:digraph.vertex()) => Clarity.tree()}
  defp collect_tree_info(graph, queue, visited_map) do
    case :queue.out(queue) do
      {:empty, _} ->
        visited_map

      {{:value, current_vertex}, queue_tail} ->
        {updated_visited_map, updated_queue} =
          Enum.reduce(
            :digraph.out_edges(graph, current_vertex),
            {visited_map, queue_tail},
            fn edge_id, {vis_acc, q_acc} ->
              {_, source_vertex, target_vertex, edge_label} = :digraph.edge(graph, edge_id)

              child_vertex =
                if current_vertex == source_vertex, do: target_vertex, else: source_vertex

              if Map.has_key?(vis_acc, child_vertex) do
                # Already placed elsewhere (shorter or equal path) → skip
                {vis_acc, q_acc}
              else
                child_stub = %{vertex: child_vertex, children: %{}}
                vis_with_child = Map.put(vis_acc, child_vertex, child_stub)

                parent_stub = Map.fetch!(vis_with_child, current_vertex)

                updated_parent_stub =
                  Map.update(
                    parent_stub,
                    :children,
                    %{edge_label => [child_vertex]},
                    fn child_map ->
                      Map.update(child_map, edge_label, [child_vertex], &[child_vertex | &1])
                    end
                  )

                vis_parent_fixed = Map.put(vis_with_child, current_vertex, updated_parent_stub)
                {vis_parent_fixed, :queue.in(child_vertex, q_acc)}
              end
            end
          )

        collect_tree_info(graph, updated_queue, updated_visited_map)
    end
  end

  @spec build_tree(
          visited_map :: %{required(:digraph.vertex()) => Clarity.tree()},
          vertex_id :: :digraph.vertex()
        ) :: Clarity.tree()
  defp build_tree(visited_map, vertex_id) do
    %{children: raw_children} = Map.fetch!(visited_map, vertex_id)

    concrete_children =
      Map.new(raw_children, fn {label, child_id_list} ->
        {label, Enum.map(child_id_list, &build_tree(visited_map, &1))}
      end)

    %{node: vertex_id, children: concrete_children}
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
