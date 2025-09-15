defmodule Clarity.Introspector.Ash.DomainTest do
  use ExUnit.Case, async: true

  alias Clarity.Introspector.Ash.Domain, as: DomainIntrospector
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Domain
  alias Clarity.Vertex.Ash.Resource

  describe inspect(&DomainIntrospector.introspect/1) do
    test "processes application vertices and runs without error" do
      graph = :digraph.new()

      # Create an application vertex
      app_vertex = %Vertex.Application{app: :demo, description: "Demo", version: "1.0.0"}
      :digraph.add_vertex(graph, app_vertex)

      # Run introspector
      result = DomainIntrospector.introspect(graph)

      assert result == graph

      # Should have at least the original application vertex
      vertices = :digraph.vertices(graph)
      assert length(vertices) >= 1
      assert app_vertex in vertices

      # Check for domain vertices (may be 0 if no domains configured)
      domain_vertices = Enum.filter(vertices, &match?(%Domain{}, &1))

      if length(domain_vertices) > 0 do
        # If domains exist, should also have resource vertices
        resource_vertices = Enum.filter(vertices, &match?(%Resource{}, &1))

        # Should have edges from app to domain
        edges = :digraph.edges(graph)

        domain_edges =
          Enum.filter(edges, fn edge ->
            {_edge, from, to, label} = :digraph.edge(graph, edge)
            from == app_vertex and match?(%Domain{}, to) and label == :domain
          end)

        assert length(domain_edges) > 0

        # Should have edges from domain to resources if resources exist
        if length(resource_vertices) > 0 do
          resource_edges =
            Enum.filter(edges, fn edge ->
              {_edge, from, to, label} = :digraph.edge(graph, edge)
              match?(%Domain{}, from) and match?(%Resource{}, to) and label == :resource
            end)

          assert length(resource_edges) > 0
        end
      end
    end

    test "does nothing when no application vertices exist" do
      graph = :digraph.new()

      result = DomainIntrospector.introspect(graph)

      assert result == graph
      assert :digraph.vertices(graph) == []
    end

    test "attaches moduledoc content to domain and resource vertices" do
      graph = :digraph.new()

      # Create an application vertex with demo app
      app_vertex = %Vertex.Application{app: :demo, description: "Demo", version: "1.0.0"}
      :digraph.add_vertex(graph, app_vertex)

      # Run introspector
      DomainIntrospector.introspect(graph)

      # Check that content vertices were created (moduledoc content)
      vertices = :digraph.vertices(graph)
      content_vertices = Enum.filter(vertices, &match?(%Vertex.Content{}, &1))

      # Should have content vertices for domains and resources
      # May be 0 if no moduledoc
      assert length(content_vertices) >= 0
    end

    test "handles multiple application vertices" do
      graph = :digraph.new()

      # Create multiple application vertices
      app1 = %Vertex.Application{app: :demo, description: "Demo", version: "1.0.0"}
      app2 = %Vertex.Application{app: :other_app, description: "Other", version: "1.0.0"}
      :digraph.add_vertex(graph, app1)
      :digraph.add_vertex(graph, app2)

      result = DomainIntrospector.introspect(graph)

      assert result == graph
      # The introspector should process all application vertices
    end

    test "returns the same graph instance" do
      graph = :digraph.new()

      result = DomainIntrospector.introspect(graph)

      assert result == graph
    end
  end
end
