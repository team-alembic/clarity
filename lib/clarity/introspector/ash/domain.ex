case Code.ensure_loaded(Ash) do
  {:module, Ash} ->
    defmodule Clarity.Introspector.Ash.Domain do
      @moduledoc false

      @behaviour Clarity.Introspector

      alias Clarity.Vertex

      @impl Clarity.Introspector
      def introspect(graph) do
        for %Vertex.Application{app: app} = app_vertex <- :digraph.vertices(graph),
            {domain, resources} <- Ash.Info.domains_and_resources(app) do
          domain_vertex = %Vertex.Ash.Domain{domain: domain}

          domain_vertex =
            :digraph.add_vertex(graph, domain_vertex, Vertex.unique_id(domain_vertex))

          :digraph.add_edge(graph, app_vertex, domain_vertex, :domain)

          Clarity.Introspector.attach_moduledoc_content(domain, graph, domain_vertex)

          for resource <- resources do
            resource_vertex = %Vertex.Ash.Resource{resource: resource}

            resource_vertex =
              :digraph.add_vertex(graph, resource_vertex, Vertex.unique_id(resource_vertex))

            :digraph.add_edge(graph, domain_vertex, resource_vertex, :resource)

            Clarity.Introspector.attach_moduledoc_content(resource, graph, resource_vertex)
          end
        end

        graph
      end
    end

  _ ->
    defmodule Clarity.Introspector.Ash.Domain do
      @moduledoc false

      @behaviour Clarity.Introspector

      @impl Clarity.Introspector
      def introspect(graph), do: graph
    end
end
