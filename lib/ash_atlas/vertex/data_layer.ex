defmodule AshAtlas.Vertex.DataLayer do
  @type t() :: %__MODULE__{
          data_layer: Ash.DataLayer.t()
        }
  @enforce_keys [:data_layer]
  defstruct [:data_layer]

  defimpl AshAtlas.Vertex do
    def unique_id(%{data_layer: data_layer}), do: "data_layer:#{inspect(data_layer)}"
    def graph_id(%{data_layer: data_layer}), do: inspect(data_layer)
    def graph_group(_vertex), do: []
    def type_label(_vertex), do: inspect(Ash.DataLayer)
    def render_name(%{data_layer: data_layer}), do: inspect(data_layer)
    def dot_shape(_vertex), do: "cylinder"
  end
end
