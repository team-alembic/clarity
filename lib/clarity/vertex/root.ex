defmodule Clarity.Vertex.Root do
  @moduledoc false
  @type t() :: %__MODULE__{}
  defstruct []

  defimpl Clarity.Vertex do
    @impl Clarity.Vertex
    def unique_id(_vertex), do: "root"

    @impl Clarity.Vertex
    def graph_id(_vertex), do: "root"

    @impl Clarity.Vertex
    def graph_group(_vertex), do: []

    @impl Clarity.Vertex
    def type_label(_vertex), do: inspect(Clarity.Vertex.Root)

    @impl Clarity.Vertex
    def render_name(_vertex), do: "Root"

    @impl Clarity.Vertex
    def dot_shape(_vertex), do: "point"

    @impl Clarity.Vertex
    def markdown_overview(_vertex), do: []

    @impl Clarity.Vertex
    def source_anno(_vertex), do: nil
  end
end
