defmodule Clarity.Introspector.Ash.DomainTest do
  use ExUnit.Case, async: true

  alias Clarity.Introspector.Ash.Domain, as: DomainIntrospector
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Domain
  alias Clarity.Vertex.Content

  describe inspect(&DomainIntrospector.introspect_vertex/2) do
    test "creates domain vertices for module vertices with domains" do
      graph = Clarity.Graph.new()
      app_vertex = %Vertex.Application{app: :clarity, description: "Clarity", version: "1.0.0"}
      module_vertex = %Vertex.Module{module: Demo.Accounts.Domain, version: :unknown}

      Clarity.Graph.add_vertex(graph, app_vertex, %Vertex.Root{})

      assert {:ok,
              [
                {:vertex, %Domain{domain: Demo.Accounts.Domain}},
                {:vertex, %Content{id: "Demo.Accounts.Domain_overview", name: "Domain Overview"}},
                {:edge, ^app_vertex, %Domain{domain: Demo.Accounts.Domain}, :domain},
                {:edge, ^module_vertex, %Domain{domain: Demo.Accounts.Domain}, :module},
                {:edge, %Domain{domain: Demo.Accounts.Domain}, %Content{id: "Demo.Accounts.Domain_overview"}, :content}
                | _
              ]} = DomainIntrospector.introspect_vertex(module_vertex, graph)
    end

    test "returns empty list for module vertices without domains" do
      graph = Clarity.Graph.new()
      module_vertex = %Vertex.Module{module: String, version: :unknown}

      assert {:ok, []} = DomainIntrospector.introspect_vertex(module_vertex, graph)
    end
  end
end
