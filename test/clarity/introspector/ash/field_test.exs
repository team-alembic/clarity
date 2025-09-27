defmodule Clarity.Introspector.Ash.FieldTest do
  use ExUnit.Case, async: true

  alias Clarity.Introspector.Ash.Field, as: FieldIntrospector
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Attribute
  alias Demo.Accounts.User

  describe inspect(&FieldIntrospector.introspect_vertex/2) do
    test "returns empty list for non-resource vertices" do
      graph = Clarity.Graph.new()
      root_vertex = %Vertex.Root{}

      assert [] = FieldIntrospector.introspect_vertex(root_vertex, graph)
    end

    test "creates field vertices for resource vertices" do
      graph = Clarity.Graph.new()
      resource_vertex = %Vertex.Ash.Resource{resource: User}

      assert [
               {:vertex, %Attribute{attribute: %{name: :id}, resource: User}},
               {:edge, ^resource_vertex, %Attribute{attribute: %{name: :id}}, :attribute},
               {:vertex, %Attribute{attribute: %{name: :first_name}, resource: User}},
               {:edge, ^resource_vertex, %Attribute{attribute: %{name: :first_name}}, :attribute}
               | _rest
             ] = FieldIntrospector.introspect_vertex(resource_vertex, graph)
    end
  end
end
