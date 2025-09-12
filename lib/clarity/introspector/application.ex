defmodule Clarity.Introspector.Application do
  @moduledoc false

  @behaviour Clarity.Introspector

  alias Clarity.Vertex

  @impl Clarity.Introspector
  def introspect(graph) do
    for app_tuple <- Application.loaded_applications(),
        %Vertex.Root{} = root_vertex <- :digraph.vertices(graph) do
      app_vertex = Vertex.Application.from_app_tuple(app_tuple)
      app_vertex = :digraph.add_vertex(graph, app_vertex, Vertex.unique_id(app_vertex))
      :digraph.add_edge(graph, root_vertex, app_vertex, :application)
    end

    graph
  end

  @impl Clarity.Introspector
  def post_introspect(graph) do
    del_vertices =
      for %Vertex.Application{} = app_vertex <- :digraph.vertices(graph),
          0 == :digraph.out_degree(graph, app_vertex),
          1 == :digraph.in_degree(graph, app_vertex),
          do: app_vertex

    :digraph.del_vertices(graph, del_vertices)

    graph
  end
end
