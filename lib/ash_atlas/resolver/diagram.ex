defmodule AshAtlas.Resolver.Diagram do
  @behaviour AshAtlas.Resolver

  alias AshAtlas.Tree.Node

  @impl AshAtlas.Resolver
  def resolve(graph) do
    for %Node.Application{app: app} = app_vertex <- :digraph.vertices(graph),
    [] != Ash.Info.domains(app) do
      content_er_vertex = %Node.Content{
        id: "er_diagram_#{app}",
        name: "ER Diagram",
        content: {:mermaid, fn -> Ash.Info.mermaid_overview(app, :entity_relationship) end}
      }
      :digraph.add_vertex(graph, content_er_vertex)
      :digraph.add_edge(graph, app_vertex, content_er_vertex, :content)

      content_class_vertex = %Node.Content{
        id: "class_diagram_#{app}",
        name: "Class Diagram",
        content: {:mermaid, fn -> Ash.Info.mermaid_overview(app, :class) end}
      }
      :digraph.add_vertex(graph, content_class_vertex)
      :digraph.add_edge(graph, app_vertex, content_class_vertex, :content)
    end

    for %Node.Domain{domain: domain} = domain_vertex <- :digraph.vertices(graph) do
      content_er_vertex = %Node.Content{
        id: "er_diagram_#{domain}",
        name: "ER Diagram",
        content: {:mermaid, fn -> Ash.Domain.Info.Diagram.mermaid_er_diagram(domain) end}
      }
      :digraph.add_vertex(graph, content_er_vertex)
      :digraph.add_edge(graph, domain_vertex, content_er_vertex, :content)

      content_class_vertex = %Node.Content{
        id: "class_diagram_#{domain}",
        name: "Class Diagram",
        content: {:mermaid, fn -> Ash.Domain.Info.Diagram.mermaid_class_diagram(domain) end}
      }
      :digraph.add_vertex(graph, content_class_vertex)
      :digraph.add_edge(graph, domain_vertex, content_class_vertex, :content)
    end

    for %Node.Resource{resource: resource} = resource_vertex <- :digraph.vertices(graph) do
      content_policy_vertex = %Node.Content{
        id: "policy_diagram_#{resource}",
        name: "Policy Diagram",
        content: {:mermaid, fn -> Ash.Policy.Chart.Mermaid.chart(resource) end}
      }

      :digraph.add_vertex(graph, content_policy_vertex)
      :digraph.add_edge(graph, resource_vertex, content_policy_vertex, :content)
    end

    graph
  end

  @impl AshAtlas.Resolver
  def post_process(graph) do
    # No post-processing needed for the domain resolver
    graph
  end
end
