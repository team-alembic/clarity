defmodule Atlas.Introspector.Action do
  @moduledoc false

  @behaviour Atlas.Introspector

  alias Ash.Resource.Info, as: ResourceInfo
  alias Atlas.Vertex

  @impl Atlas.Introspector
  def introspect(graph) do
    for %Vertex.Resource{resource: resource} = resource_vertex <- :digraph.vertices(graph),
        action <- ResourceInfo.actions(resource) do
      action_vertex = %Vertex.Action{
        action: action,
        resource: resource
      }

      action_vertex = :digraph.add_vertex(graph, action_vertex, Vertex.unique_id(action_vertex))
      :digraph.add_edge(graph, resource_vertex, action_vertex, :action)

      action_trigger_content = %Vertex.Content{
        id: Vertex.unique_id(action_vertex) <> "_trigger",
        name: "Trigger",
        content: {:live_view, {Atlas.ActionTriggerLive, %{}}}
      }

      :digraph.add_vertex(graph, action_trigger_content)
      :digraph.add_edge(graph, action_vertex, action_trigger_content, :content)
    end

    graph
  end
end
