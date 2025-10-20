defmodule Clarity.Graph.Tree do
  @moduledoc """
  Manages a tree-structured digraph that maintains shortest paths from root to all vertices.

  This module provides incremental maintenance of a tree graph where each vertex
  (except root) has exactly one incoming edge, representing the shortest path from
  the root vertex.
  """

  @doc false
  @spec add_vertex(
          tree_graph :: :digraph.graph(),
          vertex_id :: String.t()
        ) :: :ok
  def add_vertex(tree_graph, vertex_id) do
    # Just add the vertex ID to the tree graph - no path calculation needed yet
    # The path will be established when edges are added
    :digraph.add_vertex(tree_graph, vertex_id)

    :ok
  end

  @doc false
  @spec add_edge(
          tree_graph :: :digraph.graph(),
          from_vertex_id :: String.t(),
          to_vertex_id :: String.t(),
          label :: :digraph.label()
        ) :: :ok
  def add_edge(tree_graph, from_vertex_id, to_vertex_id, label) do
    maybe_add_shorter_path(tree_graph, from_vertex_id, to_vertex_id, label)

    :ok
  end

  @spec maybe_add_shorter_path(
          tree_graph :: :digraph.graph(),
          from_vertex_id :: String.t(),
          to_vertex_id :: String.t(),
          label :: :digraph.label()
        ) :: :ok
  defp maybe_add_shorter_path(tree_graph, from_vertex_id, to_vertex_id, label) do
    # Check if this edge creates a shorter path
    current_distance = distance_from_root(tree_graph, to_vertex_id)
    from_distance = distance_from_root(tree_graph, from_vertex_id)

    # Only proceed if from_vertex has a valid path (not infinity)
    # This prevents circular dependencies from causing arithmetic errors
    if from_distance != :infinity do
      new_distance = from_distance + 1

      if new_distance < current_distance do
        # Remove old path to to_vertex_id
        remove_path_to_vertex(tree_graph, to_vertex_id)

        # Add new shorter path
        :digraph.add_vertex(tree_graph, to_vertex_id)
        :digraph.add_edge(tree_graph, from_vertex_id, to_vertex_id, label)
      end
    end

    :ok
  end

  @spec distance_from_root(
          tree_graph :: :digraph.graph(),
          vertex_id :: String.t()
        ) :: non_neg_integer() | :infinity
  defp distance_from_root(tree_graph, vertex_id)
  defp distance_from_root(_tree_graph, "root"), do: 0

  defp distance_from_root(tree_graph, vertex_id) do
    case :digraph.vertex(tree_graph, vertex_id) do
      false -> :infinity
      {^vertex_id, _} -> count_edges_to_root(tree_graph, vertex_id, 0)
    end
  end

  @spec count_edges_to_root(
          tree_graph :: :digraph.graph(),
          vertex_id :: String.t(),
          count :: non_neg_integer()
        ) :: non_neg_integer() | :infinity
  defp count_edges_to_root(tree_graph, vertex_id, count)
  defp count_edges_to_root(_tree_graph, "root", count), do: count

  defp count_edges_to_root(tree_graph, vertex_id, count) do
    case :digraph.in_edges(tree_graph, vertex_id) do
      [] ->
        :infinity

      [edge_id] ->
        {_, from_v, _, _} = :digraph.edge(tree_graph, edge_id)
        count_edges_to_root(tree_graph, from_v, count + 1)

      # Should never happen in a proper tree
      _ ->
        :infinity
    end
  end

  @spec remove_path_to_vertex(
          tree_graph :: :digraph.graph(),
          vertex_id :: String.t()
        ) :: :ok
  defp remove_path_to_vertex(tree_graph, vertex_id) do
    # Remove all descendants first (DFS)
    descendants = get_all_descendants(tree_graph, vertex_id)

    Enum.each(descendants ++ [vertex_id], fn
      "root" -> :ok
      vertex_id -> :digraph.del_vertex(tree_graph, vertex_id)
    end)
  end

  @spec get_all_descendants(
          tree_graph :: :digraph.graph(),
          vertex_id :: String.t()
        ) :: [String.t()]
  defp get_all_descendants(tree_graph, vertex_id) do
    children =
      tree_graph
      |> :digraph.out_edges(vertex_id)
      |> Enum.map(fn edge_id ->
        {_, _, to_v, _} = :digraph.edge(tree_graph, edge_id)
        to_v
      end)

    children ++ Enum.flat_map(children, &get_all_descendants(tree_graph, &1))
  end
end
