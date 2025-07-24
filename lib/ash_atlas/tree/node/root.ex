defmodule AshAtlas.Tree.Node.Root do
  @type t() :: %__MODULE__{}
  defstruct []

  defimpl AshAtlas.Tree.Node do
    def unique_id(_), do: "root"
    def graph_id(_), do: "root"
    def render_name(_), do: "Root"
    def dot_shape(_node), do: "point"
  end
end
