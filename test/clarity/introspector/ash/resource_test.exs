defmodule Clarity.Introspector.Ash.ResourceTest do
  use ExUnit.Case, async: true

  alias Clarity.Introspector.Ash.Resource, as: ResourceIntrospector
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Domain
  alias Clarity.Vertex.Ash.Resource
  alias Demo.Accounts.User

  describe inspect(&ResourceIntrospector.introspect_vertex/2) do
    test "returns empty list for non-domain vertices" do
      graph = Clarity.Graph.new()
      root_vertex = %Vertex.Root{}

      assert [] = ResourceIntrospector.introspect_vertex(root_vertex, graph)
    end

    test "creates resource vertices for domain vertices" do
      graph = Clarity.Graph.new()
      domain_vertex = %Domain{domain: Demo.Accounts.Domain}

      assert [
               {:vertex, %Resource{resource: User}},
               {:edge, ^domain_vertex, %Resource{resource: User}, :resource}
             ] = ResourceIntrospector.introspect_vertex(domain_vertex, graph)
    end
  end
end
