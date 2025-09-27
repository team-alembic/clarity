defmodule Clarity.Introspector.Ash.DataLayerTest do
  use ExUnit.Case, async: true

  alias Ash.DataLayer.Simple
  alias Clarity.Introspector.Ash.DataLayer, as: DataLayerIntrospector
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.DataLayer
  alias Clarity.Vertex.Root
  alias Demo.Accounts.User

  describe inspect(&DataLayerIntrospector.introspect_vertex/2) do
    test "returns empty list for non-resource vertices" do
      graph = Clarity.Graph.new()
      root_vertex = %Root{}

      assert [] = DataLayerIntrospector.introspect_vertex(root_vertex, graph)
    end

    test "creates data layer vertices for resource vertices" do
      graph = Clarity.Graph.new()

      module_vertex = %Vertex.Module{module: Simple}
      resource_vertex = %Vertex.Ash.Resource{resource: User}

      Clarity.Graph.add_vertex(graph, module_vertex, %Root{})

      assert [
               {:vertex, %DataLayer{data_layer: Simple}},
               {:edge, nil, %DataLayer{data_layer: Simple}, :data_layer},
               {:edge, ^resource_vertex, %DataLayer{data_layer: Simple}, :data_layer},
               {:edge, ^module_vertex, %DataLayer{data_layer: Simple}, :module}
               | _
             ] = DataLayerIntrospector.introspect_vertex(resource_vertex, graph)
    end
  end
end
