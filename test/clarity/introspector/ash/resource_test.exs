defmodule Clarity.Introspector.Ash.ResourceTest do
  use ExUnit.Case, async: true

  alias Clarity.Introspector.Ash.Resource, as: ResourceIntrospector
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Domain
  alias Clarity.Vertex.Ash.Resource
  alias Clarity.Vertex.Content
  alias Demo.Accounts.User

  describe inspect(&ResourceIntrospector.introspect_vertex/2) do
    test "creates resource vertices for module vertices" do
      graph = Clarity.Graph.new()
      domain_vertex = %Domain{domain: Demo.Accounts.Domain}
      module_vertex = %Vertex.Module{module: User, version: :unknown}

      Clarity.Graph.add_vertex(graph, domain_vertex, %Vertex.Root{})

      assert {:ok,
              [
                {:vertex, %Resource{resource: User}},
                {:vertex, %Content{id: "Demo.Accounts.User_overview"}},
                {:edge, ^module_vertex, %Resource{resource: User}, :resource},
                {:edge, %Resource{resource: User}, %Content{id: "Demo.Accounts.User_overview"}, :content},
                {:edge, ^domain_vertex, %Resource{resource: User}, :resource}
                | _
              ]} = ResourceIntrospector.introspect_vertex(module_vertex, graph)
    end
  end
end
