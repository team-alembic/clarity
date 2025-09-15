defmodule Clarity.Introspector.Ash.FieldTest do
  use ExUnit.Case, async: true

  alias Clarity.Introspector.Ash.Field, as: FieldIntrospector
  alias Clarity.Vertex
  alias Demo.Accounts.User

  describe inspect(&FieldIntrospector.introspect/1) do
    test "does nothing when no resource vertices exist" do
      graph = :digraph.new()

      # Add an application vertex but no resource vertices
      app_vertex = %Vertex.Application{app: :test_app, description: "Test", version: "1.0.0"}
      :digraph.add_vertex(graph, app_vertex, Vertex.unique_id(app_vertex))

      result = FieldIntrospector.introspect(graph)

      assert result == graph
      vertices = :digraph.vertices(graph)
      assert length(vertices) == 1
      assert app_vertex in vertices
    end

    test "creates field vertices for User resource attributes and calculations" do
      graph = :digraph.new()

      # Create a resource vertex using the demo user resource
      resource_vertex = %Vertex.Ash.Resource{resource: User}
      :digraph.add_vertex(graph, resource_vertex, Vertex.unique_id(resource_vertex))

      result = FieldIntrospector.introspect(graph)

      assert result == graph

      vertices = :digraph.vertices(graph)

      # Check for attribute vertices
      attribute_vertices = Enum.filter(vertices, &match?(%Vertex.Ash.Attribute{}, &1))
      assert length(attribute_vertices) > 0

      # Verify at least one specific attribute exists (first_name)
      first_name_vertex = Enum.find(attribute_vertices, &(&1.attribute.name == :first_name))
      assert first_name_vertex
      assert first_name_vertex.resource == User

      # Check for calculation vertices
      calculation_vertices = Enum.filter(vertices, &match?(%Vertex.Ash.Calculation{}, &1))
      assert length(calculation_vertices) > 0

      # Verify at least one specific calculation exists (is_super_admin?)
      super_admin_vertex = Enum.find(calculation_vertices, &(&1.calculation.name == :is_super_admin?))
      assert super_admin_vertex
      assert super_admin_vertex.resource == User

      # Verify field vertices are connected to the resource vertex with correct edge labels
      edges = :digraph.in_edges(graph, first_name_vertex)
      assert length(edges) == 1
      [edge] = edges
      {^edge, ^resource_vertex, ^first_name_vertex, :attribute} = :digraph.edge(graph, edge)

      edges = :digraph.in_edges(graph, super_admin_vertex)
      assert length(edges) == 1
      [edge] = edges
      {^edge, ^resource_vertex, ^super_admin_vertex, :calculation} = :digraph.edge(graph, edge)
    end

    test "returns the same graph instance" do
      graph = :digraph.new()

      result = FieldIntrospector.introspect(graph)

      assert result == graph
    end
  end
end
