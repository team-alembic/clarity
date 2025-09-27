case Code.ensure_loaded(Ash) do
  {:module, Ash} ->
    defmodule Clarity.Introspector.Ash.Action do
      @moduledoc false

      @behaviour Clarity.Introspector

      alias Ash.Resource.Info, as: ResourceInfo
      alias Clarity.Vertex.Ash.Action
      alias Clarity.Vertex.Ash.Resource

      @impl Clarity.Introspector
      def source_vertex_types, do: [Resource]

      @impl Clarity.Introspector
      def introspect_vertex(%Resource{resource: resource} = resource_vertex, _graph) do
        resource
        |> ResourceInfo.actions()
        |> Enum.flat_map(fn action ->
          action_vertex = %Action{
            action: action,
            resource: resource
          }

          [
            {:vertex, action_vertex},
            {:edge, resource_vertex, action_vertex, :action}
          ]
        end)
      end

      def introspect_vertex(_vertex, _graph), do: []
    end

  _ ->
    defmodule Clarity.Introspector.Ash.Action do
      @moduledoc false

      @behaviour Clarity.Introspector

      @impl Clarity.Introspector
      def source_vertex_types, do: []

      @impl Clarity.Introspector
      def introspect_vertex(_vertex, _graph), do: []
    end
end
