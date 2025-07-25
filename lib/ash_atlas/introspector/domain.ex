defmodule AshAtlas.Introspector.Domain do
  @moduledoc false

  @behaviour AshAtlas.Introspector

  alias AshAtlas.Vertex

  @impl AshAtlas.Introspector
  def introspect(graph) do
    for %Vertex.Application{app: app} = app_vertex <- :digraph.vertices(graph),
        {domain, resources} <- Ash.Info.domains_and_resources(app) do
      domain_vertex = %Vertex.Domain{domain: domain}
      domain_vertex = :digraph.add_vertex(graph, domain_vertex, Vertex.unique_id(domain_vertex))
      :digraph.add_edge(graph, app_vertex, domain_vertex, :domain)

      AshAtlas.Introspector.attach_moduledoc_content(domain, graph, domain_vertex)

      for resource <- resources do
        resource_vertex = %Vertex.Resource{resource: resource}

        resource_vertex =
          :digraph.add_vertex(graph, resource_vertex, Vertex.unique_id(resource_vertex))

        :digraph.add_edge(graph, domain_vertex, resource_vertex, :resource)

        AshAtlas.Introspector.attach_moduledoc_content(resource, graph, resource_vertex)
      end
    end

    graph
  end
end
