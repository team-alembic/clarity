case Code.ensure_loaded(Ash) do
  {:module, Ash} ->
    defmodule Clarity.Introspector.Ash.DataLayer do
      @moduledoc false

      @behaviour Clarity.Introspector

      alias Ash.Resource.Info
      alias Clarity.Vertex
      alias Clarity.Vertex.Ash.Resource

      @impl Clarity.Introspector
      def introspect(graph) do
        app_vertices =
          graph
          |> :digraph.vertices()
          |> Enum.filter(&match?(%Vertex.Application{}, &1))
          |> Map.new(&{&1.app, &1})

        data_layer_vertices =
          graph
          |> :digraph.vertices()
          |> Enum.filter(&match?(%Resource{}, &1))
          |> Enum.map(& &1.resource)
          |> Enum.map(&Info.data_layer/1)
          |> Enum.uniq()
          |> Map.new(fn data_layer ->
            data_layer_vertex = %Vertex.Ash.DataLayer{data_layer: data_layer}
            :digraph.add_vertex(graph, data_layer_vertex, Vertex.unique_id(data_layer_vertex))

            app = Application.get_application(data_layer)
            app_vertex = Map.fetch!(app_vertices, app)

            :digraph.add_edge(graph, app_vertex, data_layer_vertex, :data_layer)

            Clarity.Introspector.attach_moduledoc_content(data_layer, graph, data_layer_vertex)

            {data_layer, data_layer_vertex}
          end)

        for %Resource{resource: resource} = resource_vertex <- :digraph.vertices(graph),
            data_layer = Info.data_layer(resource) do
          data_layer_vertex = Map.fetch!(data_layer_vertices, data_layer)
          :digraph.add_edge(graph, resource_vertex, data_layer_vertex, :data_layer)
        end

        graph
      end
    end

  _ ->
    defmodule Clarity.Introspector.Ash.DataLayer do
      @moduledoc false

      @behaviour Clarity.Introspector

      @impl Clarity.Introspector
      def introspect(graph), do: graph
    end
end
