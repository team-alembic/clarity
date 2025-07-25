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

      for resource <- resources do
        resource_vertex = %Vertex.Resource{resource: resource}

        resource_vertex =
          :digraph.add_vertex(graph, resource_vertex, Vertex.unique_id(resource_vertex))

        :digraph.add_edge(graph, domain_vertex, resource_vertex, :resource)

        test_content_vertex = %Vertex.Content{
          id: Vertex.unique_id(resource_vertex) <> "_test",
          name: "Test Markdown",
          content:
            {:markdown,
             """
             # Title

             * List

             `code`
             """}
        }

        :digraph.add_vertex(graph, test_content_vertex)
        :digraph.add_edge(graph, resource_vertex, test_content_vertex, :content)
      end
    end

    graph
  end
end
