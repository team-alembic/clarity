case Code.ensure_loaded(Phoenix.Endpoint) do
  {:module, Phoenix.Endpoint} ->
    defmodule Atlas.Introspector.Phoenix.Endpoint do
      @moduledoc false

      @behaviour Atlas.Introspector

      alias Atlas.Vertex

      @impl Atlas.Introspector
      def introspect(graph) do
        for %Vertex.Application{app: app} = app_vertex <- :digraph.vertices(graph),
            endpoint <- endpoints(app) do
          endpoint_vertex = %Vertex.Phoenix.Endpoint{endpoint: endpoint}

          endpoint_vertex =
            :digraph.add_vertex(graph, endpoint_vertex, Vertex.unique_id(endpoint_vertex))

          :digraph.add_edge(graph, app_vertex, endpoint_vertex, "endpoint")
        end

        graph
      end

      @spec endpoints(app :: Application.app()) :: [module()]
      defp endpoints(app) do
        for module <- Application.spec(app, :modules) || [],
            match?({:module, ^module}, Code.ensure_loaded(module)),
            attributes = module.module_info(:attributes),
            behaviours = attributes |> Keyword.get_values(:behaviour) |> List.flatten(),
            Phoenix.Endpoint in behaviours,
            do: module
      end
    end

  _ ->
    defmodule Atlas.Introspector.Phoenix.Endpoint do
      @moduledoc false

      @behaviour Atlas.Introspector

      @impl Atlas.Introspector
      def introspect(graph), do: graph
    end
end
