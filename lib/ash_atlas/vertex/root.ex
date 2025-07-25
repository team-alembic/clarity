defmodule AshAtlas.Vertex.Root do
  @moduledoc false
  @type t() :: %__MODULE__{}
  defstruct []

  defimpl AshAtlas.Vertex do
    @impl AshAtlas.Vertex
    def unique_id(_vertex), do: "root"

    @impl AshAtlas.Vertex
    def graph_id(_vertex), do: "root"

    @impl AshAtlas.Vertex
    def graph_group(_vertex), do: []

    @impl AshAtlas.Vertex
    def type_label(_vertex), do: inspect(AshAtlas.Vertex.Root)

    @impl AshAtlas.Vertex
    def render_name(_vertex), do: "Root"

    @impl AshAtlas.Vertex
    def dot_shape(_vertex), do: "point"
  end
end
