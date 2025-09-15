defmodule Clarity.Introspector.Ash.ActionTest do
  use ExUnit.Case, async: true

  alias Clarity.Introspector.Ash.Action, as: ActionIntrospector
  alias Clarity.Vertex
  alias Demo.Accounts.User

  describe inspect(&ActionIntrospector.introspect/1) do
    test "does nothing when no resource vertices exist" do
      graph = :digraph.new()

      # Add an application vertex but no resource vertices
      app_vertex = %Vertex.Application{app: :test_app, description: "Test", version: "1.0.0"}
      :digraph.add_vertex(graph, app_vertex, Vertex.unique_id(app_vertex))

      result = ActionIntrospector.introspect(graph)

      assert result == graph
      vertices = :digraph.vertices(graph)
      assert length(vertices) == 1
      assert app_vertex in vertices
    end

    test "creates action vertices for each action in resource vertices" do
      graph = :digraph.new()

      # Create a resource vertex using the demo user resource
      resource_vertex = %Vertex.Ash.Resource{resource: User}
      :digraph.add_vertex(graph, resource_vertex, Vertex.unique_id(resource_vertex))

      result = ActionIntrospector.introspect(graph)

      assert result == graph

      vertices = :digraph.vertices(graph)
      action_vertices = Enum.filter(vertices, &match?(%Vertex.Ash.Action{}, &1))

      # The demo user has many actions: me, read, by_id, should_be_hidden, by_name, create, update, update2, destroy
      assert length(action_vertices) > 0

      # Check that actions are connected to the resource vertex
      for action_vertex <- action_vertices do
        assert action_vertex.resource == User
        edges = :digraph.in_edges(graph, action_vertex)
        assert length(edges) == 1

        [edge] = edges
        {^edge, ^resource_vertex, ^action_vertex, :action} = :digraph.edge(graph, edge)
      end
    end

    test "returns the same graph instance" do
      graph = :digraph.new()

      result = ActionIntrospector.introspect(graph)

      assert result == graph
    end
  end
end
