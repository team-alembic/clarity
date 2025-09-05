defmodule Atlas.Introspector.Root do
  @moduledoc false

  @behaviour Atlas.Introspector

  alias Atlas.Vertex

  @impl Atlas.Introspector
  def introspect(graph) do
    root_vertex = %Vertex.Root{}
    _root_vertex = :digraph.add_vertex(graph, root_vertex, Vertex.unique_id(root_vertex))

    graph
  end
end
