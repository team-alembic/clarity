defmodule Clarity.Introspector.Ash.DataLayerTest do
  use ExUnit.Case, async: true

  alias Ash.DataLayer.Ets
  alias Clarity.Introspector.Ash.DataLayer, as: DataLayerIntrospector
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.DataLayer
  alias Clarity.Vertex.Root
  alias Demo.Accounts.User

  describe inspect(&DataLayerIntrospector.introspect_vertex/2) do
    test "creates data layer vertices for resource vertices" do
      graph = Clarity.Graph.new()

      module_vertex = %Vertex.Module{module: Ets}
      resource_vertex = %Vertex.Ash.Resource{resource: User}

      Clarity.Graph.add_vertex(graph, module_vertex, %Root{})

      assert {:ok,
              [
                {:vertex, %DataLayer{data_layer: Ets}},
                {:edge, nil, %DataLayer{data_layer: Ets}, :data_layer},
                {:edge, ^resource_vertex, %DataLayer{data_layer: Ets}, :data_layer},
                {:edge, ^module_vertex, %DataLayer{data_layer: Ets}, :module}
                | _
              ]} = DataLayerIntrospector.introspect_vertex(resource_vertex, graph)
    end
  end
end
