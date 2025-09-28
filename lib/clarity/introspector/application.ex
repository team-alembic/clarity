defmodule Clarity.Introspector.Application do
  @moduledoc false

  @behaviour Clarity.Introspector

  alias Clarity.Vertex

  @impl Clarity.Introspector
  def source_vertex_types, do: [Clarity.Vertex.Root]

  @impl Clarity.Introspector
  def introspect_vertex(%Vertex.Root{} = root_vertex, _graph) do
    entries =
      Enum.flat_map(Application.loaded_applications(), fn app_tuple ->
        app_vertex = Vertex.Application.from_app_tuple(app_tuple)

        [
          {:vertex, app_vertex},
          {:edge, root_vertex, app_vertex, :application}
        ]
      end)

    {:ok, entries}
  end
end
