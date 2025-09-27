defmodule Clarity.Introspector.Ash.ActionTest do
  use ExUnit.Case, async: true

  alias Clarity.Introspector.Ash.Action, as: ActionIntrospector
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Action
  alias Demo.Accounts.User

  describe inspect(&ActionIntrospector.introspect_vertex/2) do
    test "returns empty list for non-resource vertices" do
      graph = Clarity.Graph.new()
      root_vertex = %Vertex.Root{}

      assert [] = ActionIntrospector.introspect_vertex(root_vertex, graph)
    end

    test "creates action vertices for resource vertices" do
      graph = Clarity.Graph.new()
      resource_vertex = %Vertex.Ash.Resource{resource: User}

      assert [
               {:vertex, %Action{action: %{name: :me}, resource: User}},
               {:edge, ^resource_vertex, %Action{action: %{name: :me}}, :action},
               {:vertex, %Action{action: %{name: :read}, resource: User}},
               {:edge, ^resource_vertex, %Action{action: %{name: :read}}, :action}
               | _rest
             ] = ActionIntrospector.introspect_vertex(resource_vertex, graph)
    end
  end
end
