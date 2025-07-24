defmodule AshAtlas.Resolver.DataLayer do
  @behaviour AshAtlas.Resolver

  alias AshAtlas.Tree.Node

  @impl AshAtlas.Resolver
  def resolve(graph) do
    app_vertices =
      graph
      |> :digraph.vertices()
      |> Enum.filter(&match?(%Node.Application{}, &1))
      |> Map.new(&{&1.app, &1})

    data_layer_vertices =
      graph
      |> :digraph.vertices()
      |> Enum.filter(&match?(%Node.Resource{}, &1))
      |> Enum.map(& &1.resource)
      |> Enum.map(&Ash.Resource.Info.data_layer/1)
      |> Enum.uniq()
      |> Map.new(fn data_layer ->
        data_layer_vertex = %Node.DataLayer{data_layer: data_layer}
        :digraph.add_vertex(graph, data_layer_vertex, Node.unique_id(data_layer_vertex))

        app = Application.get_application(data_layer)
        app_vertex = Map.fetch!(app_vertices, app)

        :digraph.add_edge(graph, app_vertex, data_layer_vertex, "data_layer")

        {data_layer, data_layer_vertex}
      end)

    for %Node.Resource{resource: resource} = resource_vertex <- :digraph.vertices(graph),
        data_layer = Ash.Resource.Info.data_layer(resource) do
      data_layer_vertex = Map.fetch!(data_layer_vertices, data_layer)
      :digraph.add_edge(graph, resource_vertex, data_layer_vertex, "data_layer")
    end

    graph
  end

  @impl AshAtlas.Resolver
  def post_process(graph) do
    # No post-processing needed for the domain resolver
    graph
  end
end
