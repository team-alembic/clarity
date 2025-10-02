defmodule Clarity.Vertex.Root do
  @moduledoc """
  Vertex implementation for the root node in the Clarity graph.
  """
  @type t() :: %__MODULE__{}
  defstruct []

  defimpl Clarity.Vertex do
    alias Clarity.Vertex.Util

    @impl Clarity.Vertex
    def id(_vertex), do: Util.id(@for, [])

    @impl Clarity.Vertex
    def type_label(_vertex), do: "Root"

    @impl Clarity.Vertex
    def name(_vertex), do: "Root"
  end

  defimpl Clarity.Vertex.GraphShapeProvider do
    @impl Clarity.Vertex.GraphShapeProvider
    def shape(_vertex), do: "point"
  end
end
