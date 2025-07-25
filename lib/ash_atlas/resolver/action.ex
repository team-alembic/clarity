defmodule AshAtlas.Resolver.Action do
  @behaviour AshAtlas.Resolver

  alias AshAtlas.Tree.Node

  @impl AshAtlas.Resolver
  def resolve(graph) do
    for %Node.Resource{resource: resource} = resource_vertex <- :digraph.vertices(graph),
        action <- Ash.Resource.Info.actions(resource) do
      action_node = %Node.Action{
        action: action,
        resource: resource
      }

      action_vertex = :digraph.add_vertex(graph, action_node, Node.unique_id(action_node))
      :digraph.add_edge(graph, resource_vertex, action_vertex, :action)

      action_trigger_content = %Node.Content{
        id: Node.unique_id(action_node) <> "_trigger",
        name: "Trigger",
        content: {:live_view, {AshAtlas.ActionTriggerLive, %{}}}
      }

      :digraph.add_vertex(graph, action_trigger_content)
      :digraph.add_edge(graph, action_vertex, action_trigger_content, :content)
    end

    graph
  end

  @impl AshAtlas.Resolver
  def post_process(graph) do
    # No post-processing needed for the domain resolver
    graph
  end
end
