case Code.ensure_loaded(Phoenix.Router) do
  {:module, Phoenix.Router} ->
    defmodule Clarity.Introspector.Phoenix.Router do
      @moduledoc false

      @behaviour Clarity.Introspector

      alias Clarity.Vertex
      alias Clarity.Vertex.Phoenix.Router, as: RouterVertex

      @impl Clarity.Introspector
      def source_vertex_types, do: [Clarity.Vertex.Module]

      @impl Clarity.Introspector
      def introspect_vertex(%Vertex.Module{module: module} = module_vertex, graph) do
        if router?(module) do
          router_vertex = %RouterVertex{router: module}
          app = Application.get_application(module)

          app_vertex =
            graph
            |> Clarity.Graph.vertices()
            |> Enum.find(&match?(%Vertex.Application{app: ^app}, &1))

          [
            {:vertex, router_vertex},
            {:edge, module_vertex, router_vertex, "router"},
            {:edge, app_vertex, router_vertex, "router"}
            | Clarity.Introspector.moduledoc_content(module, router_vertex)
          ]
        else
          []
        end
      end

      def introspect_vertex(_vertex, _graph), do: []

      @spec router?(module :: module()) :: boolean()
      defp router?(module) do
        case Code.ensure_loaded(module) do
          {:module, ^module} ->
            attributes = module.module_info(:attributes)
            behaviours = attributes |> Keyword.get_values(:behaviour) |> List.flatten()
            Plug in behaviours and function_exported?(module, :__routes__, 0)

          _ ->
            false
        end
      end
    end

  _ ->
    defmodule Clarity.Introspector.Phoenix.Router do
      @moduledoc false

      @behaviour Clarity.Introspector

      @impl Clarity.Introspector
      def source_vertex_types, do: []

      @impl Clarity.Introspector
      def introspect_vertex(_vertex, _graph), do: []
    end
end
