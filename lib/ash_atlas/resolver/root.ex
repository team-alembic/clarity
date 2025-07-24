defmodule AshAtlas.Resolver.Root do
  @behaviour AshAtlas.Resolver

  alias AshAtlas.Tree.Node

  @impl AshAtlas.Resolver
  def resolve(graph) do
    root_node = %Node.Root{}
    _root_vertex = :digraph.add_vertex(graph, root_node, Node.unique_id(root_node))

    graph
  end

  @impl AshAtlas.Resolver
  def post_process(graph) do
    # No post-processing needed for the root resolver
    graph
  end
end
