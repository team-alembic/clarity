defmodule Clarity.Introspector.Ash.DiagramTest do
  use ExUnit.Case, async: true

  alias Clarity.Introspector.Ash.Diagram, as: DiagramIntrospector
  alias Clarity.Vertex
  alias Demo.Accounts.User

  describe inspect(&DiagramIntrospector.introspect/1) do
    test "does nothing when no relevant vertices exist" do
      graph = :digraph.new()

      # Add a random vertex that doesn't trigger diagram creation
      root_vertex = %Vertex.Root{}
      :digraph.add_vertex(graph, root_vertex, Vertex.unique_id(root_vertex))

      result = DiagramIntrospector.introspect(graph)

      assert result == graph
      vertices = :digraph.vertices(graph)
      assert length(vertices) == 1
      assert root_vertex in vertices
    end

    test "creates content vertices for domain diagrams" do
      graph = :digraph.new()

      # Create a domain vertex which will definitely trigger diagram creation
      domain_vertex = %Vertex.Ash.Domain{domain: Demo.Accounts.Domain}
      :digraph.add_vertex(graph, domain_vertex, Vertex.unique_id(domain_vertex))

      result = DiagramIntrospector.introspect(graph)

      assert result == graph

      vertices = :digraph.vertices(graph)
      content_vertices = Enum.filter(vertices, &match?(%Vertex.Content{}, &1))

      # Should create ER and Class diagram content vertices for the domain
      assert length(content_vertices) >= 2

      # Find ER diagram content vertex
      er_content = Enum.find(content_vertices, &(&1.name == "ER Diagram"))
      assert er_content
      assert String.contains?(er_content.id, "er_diagram")

      # Find Class diagram content vertex
      class_content = Enum.find(content_vertices, &(&1.name == "Class Diagram"))
      assert class_content
      assert String.contains?(class_content.id, "class_diagram")

      # Verify content vertices are connected to the domain vertex
      for content_vertex <- [er_content, class_content] do
        edges = :digraph.in_edges(graph, content_vertex)
        assert length(edges) == 1

        [edge] = edges
        {^edge, ^domain_vertex, ^content_vertex, :content} = :digraph.edge(graph, edge)
      end
    end

    test "creates policy diagram for resource vertices" do
      graph = :digraph.new()

      # Create a resource vertex
      resource_vertex = %Vertex.Ash.Resource{resource: User}
      :digraph.add_vertex(graph, resource_vertex, Vertex.unique_id(resource_vertex))

      result = DiagramIntrospector.introspect(graph)

      assert result == graph

      vertices = :digraph.vertices(graph)
      content_vertices = Enum.filter(vertices, &match?(%Vertex.Content{}, &1))

      # Should create policy diagram content vertex
      assert length(content_vertices) >= 1

      # Find policy diagram content vertex
      policy_content = Enum.find(content_vertices, &(&1.name == "Policy Diagram"))
      assert policy_content
      assert String.contains?(policy_content.id, "policy_diagram")

      # Verify content vertex is connected to the resource vertex
      edges = :digraph.in_edges(graph, policy_content)
      assert length(edges) == 1

      [edge] = edges
      {^edge, ^resource_vertex, ^policy_content, :content} = :digraph.edge(graph, edge)
    end

    test "returns the same graph instance" do
      graph = :digraph.new()

      result = DiagramIntrospector.introspect(graph)

      assert result == graph
    end
  end
end
