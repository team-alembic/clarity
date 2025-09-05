defmodule Atlas.Vertex.Root do
  @moduledoc false
  @type t() :: %__MODULE__{}
  defstruct []

  defimpl Atlas.Vertex do
    @impl Atlas.Vertex
    def unique_id(_vertex), do: "root"

    @impl Atlas.Vertex
    def graph_id(_vertex), do: "root"

    @impl Atlas.Vertex
    def graph_group(_vertex), do: []

    @impl Atlas.Vertex
    def type_label(_vertex), do: inspect(Atlas.Vertex.Root)

    @impl Atlas.Vertex
    def render_name(_vertex), do: "Root"

    @impl Atlas.Vertex
    def dot_shape(_vertex), do: "point"

    @impl Atlas.Vertex
    def markdown_overview(_vertex), do: []
  end
end
