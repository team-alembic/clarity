case Code.ensure_loaded(Ash) do
  {:module, Ash} ->
    defmodule Clarity.Introspector.Ash.Action do
      @moduledoc false

      @behaviour Clarity.Introspector

      alias Ash.Resource.Info, as: ResourceInfo
      alias Clarity.Vertex

      @impl Clarity.Introspector
      def dependencies, do: [Clarity.Introspector.Ash.Domain]

      @impl Clarity.Introspector
      def introspect(graph) do
        for %Vertex.Ash.Resource{resource: resource} = resource_vertex <-
              :digraph.vertices(graph),
            action <- ResourceInfo.actions(resource) do
          action_vertex = %Vertex.Ash.Action{
            action: action,
            resource: resource
          }

          action_vertex =
            :digraph.add_vertex(graph, action_vertex, Vertex.unique_id(action_vertex))

          :digraph.add_edge(graph, resource_vertex, action_vertex, :action)

          # TODO: Implement action triggers
          # action_trigger_content = %Vertex.Content{
          #   id: Vertex.unique_id(action_vertex) <> "_trigger",
          #   name: "Trigger",
          #   content: {:live_view, {Clarity.ActionTriggerLive, %{}}}
          # }

          # :digraph.add_vertex(graph, action_trigger_content)
          # :digraph.add_edge(graph, action_vertex, action_trigger_content, :content)
        end

        graph
      end
    end

  _ ->
    defmodule Clarity.Introspector.Ash.Action do
      @moduledoc false

      @behaviour Clarity.Introspector

      @impl Clarity.Introspector
      def dependencies, do: [Clarity.Introspector.Ash.Domain]

      @impl Clarity.Introspector
      def introspect(graph), do: graph
    end
end
