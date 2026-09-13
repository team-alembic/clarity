defmodule Clarity.Introspector.Ash.DomainTest do
  use ExUnit.Case, async: true

  alias Clarity.Introspector.Ash.Domain, as: DomainIntrospector
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Domain
  alias Clarity.Vertex.Ash.Resource

  describe inspect(&DomainIntrospector.introspect_vertex/2) do
    test "creates domain vertices for module vertices with domains" do
      graph = Clarity.Graph.new()
      app_vertex = %Vertex.Application{app: :clarity, description: "Clarity", version: "1.0.0"}
      module_vertex = %Vertex.Module{module: Demo.Accounts, version: :unknown}

      Clarity.Graph.add_vertex(graph, app_vertex, %Vertex.Root{})

      assert {:ok,
              [
                {:vertex, %Domain{domain: Demo.Accounts}},
                {:edge, ^app_vertex, %Domain{domain: Demo.Accounts}, :domain},
                {:edge, ^module_vertex, %Domain{domain: Demo.Accounts}, :module}
                | _
              ]} = DomainIntrospector.introspect_vertex(module_vertex, graph)
    end

    test "re-links resource vertices that already exist in the graph" do
      # Recompiling a resource also recompiles its domain module, which purges the
      # domain vertex and every edge it had. Resources that did not change are never
      # re-introspected, so the domain must re-attach them itself.
      graph = Clarity.Graph.new()
      app_vertex = %Vertex.Application{app: :clarity, description: "Clarity", version: "1.0.0"}
      module_vertex = %Vertex.Module{module: Demo.Accounts, version: :unknown}
      resource_vertex = %Resource{resource: Demo.Accounts.User}

      Clarity.Graph.add_vertex(graph, app_vertex, %Vertex.Root{})
      Clarity.Graph.add_vertex(graph, resource_vertex, %Vertex.Root{})

      assert {:ok, entries} = DomainIntrospector.introspect_vertex(module_vertex, graph)

      assert {:edge, %Domain{domain: Demo.Accounts}, resource_vertex, :resource} in entries
    end

    test "does not emit resource edges for resources missing from the graph" do
      graph = Clarity.Graph.new()
      app_vertex = %Vertex.Application{app: :clarity, description: "Clarity", version: "1.0.0"}
      module_vertex = %Vertex.Module{module: Demo.Accounts, version: :unknown}

      Clarity.Graph.add_vertex(graph, app_vertex, %Vertex.Root{})

      assert {:ok, entries} = DomainIntrospector.introspect_vertex(module_vertex, graph)

      refute Enum.any?(entries, &match?({:edge, _, %Resource{}, :resource}, &1))
    end

    test "returns empty list for module vertices without domains" do
      graph = Clarity.Graph.new()
      module_vertex = %Vertex.Module{module: String, version: :unknown}

      assert {:ok, []} = DomainIntrospector.introspect_vertex(module_vertex, graph)
    end
  end
end
