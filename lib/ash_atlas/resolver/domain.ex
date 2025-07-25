defmodule AshAtlas.Resolver.Domain do
  @behaviour AshAtlas.Resolver

  alias AshAtlas.Tree.Node

  @impl AshAtlas.Resolver
  def resolve(graph) do
    for %Node.Application{app: app} = app_vertex <- :digraph.vertices(graph),
        {domain, resources} <- Ash.Info.domains_and_resources(app) do
      domain_node = %Node.Domain{domain: domain}
      domain_vertex = :digraph.add_vertex(graph, domain_node, Node.unique_id(domain_node))
      :digraph.add_edge(graph, app_vertex, domain_vertex, :domain)

      for resource <- resources do
        resource_node = %Node.Resource{resource: resource}
        resource_vertex = :digraph.add_vertex(graph, resource_node, Node.unique_id(resource_node))
        :digraph.add_edge(graph, domain_vertex, resource_vertex, :resource)

        test_content_node = %Node.Content{
          id: Node.unique_id(resource_node) <> "_test",
          name: "Test Markdown",
          content: {:markdown, """
          # Title

          * List

          `code`
          """}
        }

        :digraph.add_vertex(graph, test_content_node)
        :digraph.add_edge(graph, resource_vertex, test_content_node, :content)
      end
    end

    graph
  end

  @impl AshAtlas.Resolver
  def post_process(graph) do
    # No post-processing needed for the domain resolver
    graph
  end
end
