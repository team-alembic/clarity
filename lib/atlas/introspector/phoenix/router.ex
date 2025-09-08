case Code.ensure_loaded(Phoenix.Router) do
  {:module, Phoenix.Router} ->
    defmodule Atlas.Introspector.Phoenix.Router do
      @moduledoc false

      @behaviour Atlas.Introspector

      alias Atlas.Vertex

      @impl Atlas.Introspector
      def introspect(graph) do
        for %Vertex.Application{app: app} = app_vertex <- :digraph.vertices(graph),
            router <- routers(app) do
          router_vertex = %Vertex.Phoenix.Router{router: router}

          router_vertex =
            :digraph.add_vertex(graph, router_vertex, Vertex.unique_id(router_vertex))

          :digraph.add_edge(graph, app_vertex, router_vertex, "router")
        end

        graph
      end

      @spec routers(app :: Application.app()) :: [module()]
      defp routers(app) do
        for module <- Application.spec(app, :modules) || [],
            match?({:module, ^module}, Code.ensure_loaded(module)),
            attributes = module.module_info(:attributes),
            behaviours = attributes |> Keyword.get_values(:behaviour) |> List.flatten(),
            Plug in behaviours,
            function_exported?(module, :__routes__, 0),
            do: module
      end
    end

  _ ->
    defmodule Atlas.Introspector.Phoenix.Router do
      @moduledoc false

      @behaviour Atlas.Introspector

      @impl Atlas.Introspector
      def introspect(graph), do: graph
    end
end
