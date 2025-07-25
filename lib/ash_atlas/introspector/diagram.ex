defmodule AshAtlas.Introspector.Diagram do
  @moduledoc false

  @behaviour AshAtlas.Introspector

  alias Ash.Domain.Info.Diagram
  alias Ash.Policy.Chart.Mermaid, as: PolicyMermaid
  alias AshAtlas.Vertex

  @impl AshAtlas.Introspector
  def introspect(graph) do
    for %Vertex.Application{app: app} = app_vertex <- :digraph.vertices(graph),
        [] != Ash.Info.domains(app) do
      content_er_vertex = %Vertex.Content{
        id: "er_diagram_#{app}",
        name: "ER Diagram",
        content: {:mermaid, fn -> Ash.Info.mermaid_overview(app, :entity_relationship) end}
      }

      :digraph.add_vertex(graph, content_er_vertex)
      :digraph.add_edge(graph, app_vertex, content_er_vertex, :content)

      content_class_vertex = %Vertex.Content{
        id: "class_diagram_#{app}",
        name: "Class Diagram",
        content: {:mermaid, fn -> Ash.Info.mermaid_overview(app, :class) end}
      }

      :digraph.add_vertex(graph, content_class_vertex)
      :digraph.add_edge(graph, app_vertex, content_class_vertex, :content)
    end

    for %Vertex.Domain{domain: domain} = domain_vertex <- :digraph.vertices(graph) do
      content_er_vertex = %Vertex.Content{
        id: "er_diagram_#{domain}",
        name: "ER Diagram",
        content: {:mermaid, fn -> Diagram.mermaid_er_diagram(domain) end}
      }

      :digraph.add_vertex(graph, content_er_vertex)
      :digraph.add_edge(graph, domain_vertex, content_er_vertex, :content)

      content_class_vertex = %Vertex.Content{
        id: "class_diagram_#{domain}",
        name: "Class Diagram",
        content: {:mermaid, fn -> Diagram.mermaid_class_diagram(domain) end}
      }

      :digraph.add_vertex(graph, content_class_vertex)
      :digraph.add_edge(graph, domain_vertex, content_class_vertex, :content)
    end

    for %Vertex.Resource{resource: resource} = resource_vertex <- :digraph.vertices(graph) do
      content_policy_vertex = %Vertex.Content{
        id: "policy_diagram_#{resource}",
        name: "Policy Diagram",
        content: {:mermaid, fn -> PolicyMermaid.chart(resource) end}
      }

      :digraph.add_vertex(graph, content_policy_vertex)
      :digraph.add_edge(graph, resource_vertex, content_policy_vertex, :content)
    end

    graph
  end
end
