defmodule Clarity.Test.DummyIntrospector do
  @moduledoc false

  @behaviour Clarity.Introspector

  @impl Clarity.Introspector
  def source_vertex_types, do: []

  @impl Clarity.Introspector
  def introspect_vertex(_vertex, _graph) do
    # Return empty for other vertices
    []
  end
end
