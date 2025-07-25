defmodule AshAtlas.Vertex.Type do
  @type t() :: %__MODULE__{
          type: Ash.Type.t()
        }
  @enforce_keys [:type]
  defstruct [:type]

  defimpl AshAtlas.Vertex do
    def unique_id(%{type: type}), do: "type:#{inspect(type)}"
    def graph_id(%{type: type}), do: inspect(type)
    def graph_group(_vertex), do: []
    def type_label(_vertex), do: inspect(Ash.Type)
    def render_name(%{type: type}), do: inspect(type)
    def dot_shape(_vertex), do: "plain"
  end
end
