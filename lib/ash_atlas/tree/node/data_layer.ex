defmodule AshAtlas.Tree.Node.DataLayer do
  @type t() :: %__MODULE__{
          data_layer: Ash.DataLayer.t()
        }
  @enforce_keys [:data_layer]
  defstruct [:data_layer]

  defimpl AshAtlas.Tree.Node do
    def unique_id(%{data_layer: data_layer}), do: "data_layer:#{inspect(data_layer)}"

    def graph_id(%{data_layer: data_layer}),
      do: "data_layer_#{data_layer |> Macro.underscore() |> String.replace(~r/[^a-z_]/, "_")}"

    def render_name(%{data_layer: data_layer}), do: inspect(data_layer)

    def dot_shape(_node), do: "cylinder"
  end
end
