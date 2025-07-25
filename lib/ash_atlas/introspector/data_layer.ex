defmodule AshAtlas.Introspector.DataLayer do
  @moduledoc false

  @behaviour AshAtlas.Introspector

  alias Ash.Resource.Info
  alias AshAtlas.Vertex

  @impl AshAtlas.Introspector
  def introspect(graph) do
    app_vertices =
      graph
      |> :digraph.vertices()
      |> Enum.filter(&match?(%Vertex.Application{}, &1))
      |> Map.new(&{&1.app, &1})

    data_layer_vertices =
      graph
      |> :digraph.vertices()
      |> Enum.filter(&match?(%Vertex.Resource{}, &1))
      |> Enum.map(& &1.resource)
      |> Enum.map(&Info.data_layer/1)
      |> Enum.uniq()
      |> Map.new(fn data_layer ->
        data_layer_vertex = %Vertex.DataLayer{data_layer: data_layer}
        :digraph.add_vertex(graph, data_layer_vertex, Vertex.unique_id(data_layer_vertex))

        app = Application.get_application(data_layer)
        app_vertex = Map.fetch!(app_vertices, app)

        :digraph.add_edge(graph, app_vertex, data_layer_vertex, :data_layer)

        {data_layer, data_layer_vertex}
      end)

    for %Vertex.Resource{resource: resource} = resource_vertex <- :digraph.vertices(graph),
        data_layer = Info.data_layer(resource) do
      data_layer_vertex = Map.fetch!(data_layer_vertices, data_layer)
      :digraph.add_edge(graph, resource_vertex, data_layer_vertex, :data_layer)
    end

    graph
  end
end
