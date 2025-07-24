defmodule AshAtlas.Tree.Node.Type do
  @type t() :: %__MODULE__{
          type: Ash.Type.t()
        }
  @enforce_keys [:type]
  defstruct [:type]

  defimpl AshAtlas.Tree.Node do
    def unique_id(%{type: type}), do: "type:#{inspect(type)}"

    def graph_id(%{type: type}),
      do: "type_#{type |> Macro.underscore() |> String.replace(~r/[^a-z_]/, "_")}"

    def render_name(%{type: type}), do: inspect(type)

    def dot_shape(_node), do: "plain"
  end
end
