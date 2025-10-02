case Code.ensure_loaded(Phoenix.Endpoint) do
  {:module, Phoenix.Endpoint} ->
    defmodule Clarity.Introspector.Phoenix.Endpoint do
      @moduledoc false

      @behaviour Clarity.Introspector

      alias Clarity.Vertex
      alias Clarity.Vertex.Phoenix.Endpoint, as: EndpointVertex

      @impl Clarity.Introspector
      def source_vertex_types, do: [Clarity.Vertex.Module]

      @impl Clarity.Introspector
      def introspect_vertex(%Vertex.Module{module: module} = module_vertex, graph) do
        if endpoint?(module) do
          endpoint_vertex = %EndpointVertex{endpoint: module}
          app = Application.get_application(module)

          app_vertex =
            graph
            |> Clarity.Graph.vertices(type: Vertex.Application, field_equal: {:app, app})
            |> List.first()

          {:ok,
           [
             {:vertex, endpoint_vertex},
             {:edge, module_vertex, endpoint_vertex, "endpoint"},
             {:edge, app_vertex, endpoint_vertex, "endpoint"}
             | Clarity.Introspector.moduledoc_content(module, endpoint_vertex)
           ]}
        else
          {:ok, []}
        end
      end

      @spec endpoint?(module :: module()) :: boolean()
      defp endpoint?(module) do
        case Code.ensure_loaded(module) do
          {:module, ^module} ->
            attributes = module.module_info(:attributes)
            behaviours = attributes |> Keyword.get_values(:behaviour) |> List.flatten()
            Phoenix.Endpoint in behaviours

          _ ->
            false
        end
      end
    end

  _ ->
    defmodule Clarity.Introspector.Phoenix.Endpoint do
      @moduledoc false

      @behaviour Clarity.Introspector

      @impl Clarity.Introspector
      def source_vertex_types, do: []

      @impl Clarity.Introspector
      def introspect_vertex(_vertex, _graph), do: {:ok, []}
    end
end
