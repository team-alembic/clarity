defmodule AshAtlas.Vertex.Root do
  @type t() :: %__MODULE__{}
  defstruct []

  defimpl AshAtlas.Vertex do
    def unique_id(_vertex), do: "root"
    def graph_id(_vertex), do: "root"
    def graph_group(_vertex), do: []
    def type_label(_vertex), do: inspect(AshAtlas.Vertex.Root)
    def render_name(_vertex), do: "Root"
    def dot_shape(_vertex), do: "point"
  end
end
