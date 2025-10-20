case Code.ensure_loaded(Ash) do
  {:module, Ash} ->
    defmodule Clarity.Introspector.Ash.DataLayer do
      @moduledoc false

      @behaviour Clarity.Introspector

      alias Ash.Resource.Info
      alias Clarity.Vertex
      alias Clarity.Vertex.Ash.DataLayer
      alias Clarity.Vertex.Ash.Resource
      alias Clarity.Vertex.Util

      @impl Clarity.Introspector
      def source_vertex_types, do: [Resource]

      @impl Clarity.Introspector
      def introspect_vertex(%Resource{resource: resource} = resource_vertex, graph) do
        data_layer = Info.data_layer(resource)
        data_layer_vertex = %DataLayer{data_layer: data_layer}
        app = Application.get_application(data_layer)

        app_vertex = Clarity.Graph.get_vertex(graph, Util.id(Vertex.Application, [app]))

        module_vertex =
          graph
          |> Clarity.Graph.vertices(
            {:and, {:==, :vertex_type, Vertex.Module}, {:==, {:field, :module}, data_layer}}
          )
          |> List.first()

        {:ok,
         [
           {:vertex, data_layer_vertex},
           {:edge, app_vertex, data_layer_vertex, :data_layer},
           {:edge, resource_vertex, data_layer_vertex, :data_layer},
           {:edge, module_vertex, data_layer_vertex, :module}
         ]}
      end
    end

  _ ->
    defmodule Clarity.Introspector.Ash.DataLayer do
      @moduledoc false

      @behaviour Clarity.Introspector

      @impl Clarity.Introspector
      def source_vertex_types, do: []

      @impl Clarity.Introspector
      def introspect_vertex(_vertex, _graph), do: {:ok, []}
    end
end
