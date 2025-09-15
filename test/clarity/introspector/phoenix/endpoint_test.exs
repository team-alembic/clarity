defmodule Clarity.Introspector.Phoenix.EndpointTest do
  use ExUnit.Case, async: true

  alias Clarity.Introspector.Phoenix.Endpoint, as: EndpointIntrospector
  alias Clarity.Vertex
  alias Clarity.Vertex.Phoenix.Endpoint

  describe inspect(&EndpointIntrospector.introspect/1) do
    test "does nothing when no application vertices exist" do
      graph = :digraph.new()

      # Add a non-application vertex
      root_vertex = %Vertex.Root{}
      :digraph.add_vertex(graph, root_vertex, Vertex.unique_id(root_vertex))

      result = EndpointIntrospector.introspect(graph)

      assert result == graph
      vertices = :digraph.vertices(graph)
      assert length(vertices) == 1
      assert root_vertex in vertices
    end

    test "creates endpoint vertices for applications with Phoenix endpoints" do
      graph = :digraph.new()

      # Create an application vertex for clarity (which has DemoWeb.Endpoint)
      clarity_app_vertex = %Vertex.Application{app: :clarity, description: "Clarity App", version: "1.0.0"}
      :digraph.add_vertex(graph, clarity_app_vertex, Vertex.unique_id(clarity_app_vertex))

      result = EndpointIntrospector.introspect(graph)

      assert result == graph

      vertices = :digraph.vertices(graph)
      endpoint_vertices = Enum.filter(vertices, &match?(%Endpoint{}, &1))

      # Should create at least one endpoint vertex (DemoWeb.Endpoint)
      assert length(endpoint_vertices) > 0

      # Find the DemoWeb.Endpoint vertex
      demo_endpoint = Enum.find(endpoint_vertices, &(&1.endpoint == DemoWeb.Endpoint))
      assert demo_endpoint

      # Verify endpoint vertex is connected to the application vertex
      edges = :digraph.in_edges(graph, demo_endpoint)
      assert length(edges) == 1

      [edge] = edges
      {^edge, ^clarity_app_vertex, ^demo_endpoint, "endpoint"} = :digraph.edge(graph, edge)
    end

    test "does nothing for applications without Phoenix endpoints" do
      graph = :digraph.new()

      # Create an application vertex for an app without endpoints
      test_app_vertex = %Vertex.Application{app: :test_app, description: "Test App", version: "1.0.0"}
      :digraph.add_vertex(graph, test_app_vertex, Vertex.unique_id(test_app_vertex))

      result = EndpointIntrospector.introspect(graph)

      assert result == graph
      vertices = :digraph.vertices(graph)
      endpoint_vertices = Enum.filter(vertices, &match?(%Endpoint{}, &1))

      # Should not create any endpoint vertices
      assert endpoint_vertices == []
    end

    test "returns the same graph instance" do
      graph = :digraph.new()

      result = EndpointIntrospector.introspect(graph)

      assert result == graph
    end
  end
end
