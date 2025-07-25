defmodule AshAtlas.Tree.Node.Root do
  @type t() :: %__MODULE__{}
  defstruct []

  defimpl AshAtlas.Tree.Node do
    def unique_id(_node), do: "root"
    def graph_id(_node), do: "root"
    def graph_group(_node), do: []
    def type_label(_node), do: inspect(AshAtlas.Tree.Node.Root)
    def render_name(_node), do: "Root"
    def dot_shape(_node), do: "point"
  end
end
