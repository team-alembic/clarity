defmodule AshAtlas do
  @spec graph() :: :digraph.t()
  def graph do
    graph = :digraph.new()
    AshAtlas.Introspector.introspect(graph)
  end

  @spec vertex_by_unique_id(graph :: :digraph.t(), unique_id :: String.t()) ::
          AshAtlas.Vertex.t() | nil
  def vertex_by_unique_id(graph, unique_id) do
    graph
    |> :digraph.vertices()
    |> Enum.find(&(AshAtlas.Vertex.unique_id(&1) == unique_id))
  end

  @spec subgraph(
          graph :: :digraph.t(),
          vertex :: AshAtlas.Vertex.t(),
          max_out_distance :: non_neg_integer(),
          max_in_distance :: non_neg_integer()
        ) ::
          :digraph.t()
  def subgraph(graph, vertex, max_out_distance, max_in_distance) do
    AshAtlas.GraphUtil.subgraph_within_steps(graph, vertex, max_out_distance, max_in_distance)
  end

  @spec tree(graph :: :digraph.t()) :: AshAtlas.GraphUtil.tree_vertex()
  def tree(graph) do
    root_vertex = vertex_by_unique_id(graph, "root")
    AshAtlas.GraphUtil.graph_to_tree(graph, root_vertex)
  end
end
