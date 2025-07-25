defmodule AshAtlas.Introspector.Root do
  @moduledoc false

  @behaviour AshAtlas.Introspector

  alias AshAtlas.Vertex

  @impl AshAtlas.Introspector
  def introspect(graph) do
    root_vertex = %Vertex.Root{}
    _root_vertex = :digraph.add_vertex(graph, root_vertex, Vertex.unique_id(root_vertex))

    graph
  end
end
