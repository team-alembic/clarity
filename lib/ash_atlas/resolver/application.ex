defmodule AshAtlas.Resolver.Application do
  @behaviour AshAtlas.Resolver

  alias AshAtlas.Tree.Node

  @impl AshAtlas.Resolver
  def resolve(graph) do
    for app_tuple <- Application.loaded_applications(),
        %Node.Root{} = root_vertex <- :digraph.vertices(graph) do
      app_node = Node.Application.from_app_tuple(app_tuple)
      app_vertex = :digraph.add_vertex(graph, app_node, Node.unique_id(app_node))
      :digraph.add_edge(graph, root_vertex, app_vertex, "application")
    end

    graph
  end

  @impl AshAtlas.Resolver
  def post_process(graph) do
    del_vertices =
      for %Node.Application{} = app_node <- :digraph.vertices(graph),
          0 == :digraph.out_degree(graph, app_node),
          1 == :digraph.in_degree(graph, app_node),
          do: app_node

    :digraph.del_vertices(graph, del_vertices)

    graph
  end
end
