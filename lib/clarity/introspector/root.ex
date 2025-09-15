defmodule Clarity.Introspector.Root do
  @moduledoc false

  @behaviour Clarity.Introspector

  alias Clarity.Vertex

  @impl Clarity.Introspector
  def dependencies, do: []

  @impl Clarity.Introspector
  def introspect(graph) do
    root_vertex = %Vertex.Root{}
    _root_vertex = :digraph.add_vertex(graph, root_vertex, Vertex.unique_id(root_vertex))

    graph
  end
end
