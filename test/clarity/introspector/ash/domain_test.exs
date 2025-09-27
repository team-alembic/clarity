defmodule Clarity.Introspector.Ash.DomainTest do
  use ExUnit.Case, async: true

  alias Clarity.Introspector.Ash.Domain, as: DomainIntrospector
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Domain

  describe inspect(&DomainIntrospector.introspect_vertex/2) do
    test "returns empty list for non-application vertices" do
      graph = Clarity.Graph.new()
      root_vertex = %Vertex.Root{}

      assert [] = DomainIntrospector.introspect_vertex(root_vertex, graph)
    end

    test "creates domain vertices for application vertices with domains" do
      graph = Clarity.Graph.new()
      app_vertex = %Vertex.Application{app: :clarity, description: "Clarity", version: "1.0.0"}

      assert [
               {:vertex, %Domain{domain: Demo.Accounts.Domain}},
               {:edge, ^app_vertex, %Domain{domain: Demo.Accounts.Domain}, :domain}
               | _
             ] = DomainIntrospector.introspect_vertex(app_vertex, graph)
    end

    test "returns empty list for application vertices without domains" do
      graph = Clarity.Graph.new()
      app_vertex = %Vertex.Application{app: :unknown_app, description: "Unknown", version: "1.0.0"}

      assert [] = DomainIntrospector.introspect_vertex(app_vertex, graph)
    end
  end
end
