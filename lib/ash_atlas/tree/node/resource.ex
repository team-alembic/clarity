defmodule AshAtlas.Tree.Node.Resource do
  @type t() :: %__MODULE__{
          resource: Ash.Resource.t()
        }
  @enforce_keys [:resource]
  defstruct [:resource]

  defimpl AshAtlas.Tree.Node do
    def unique_id(%{resource: resource}), do: "resource:#{inspect(resource)}"

    def graph_id(%{resource: resource}),
      do: "resource_#{resource |> Macro.underscore() |> String.replace(~r/[^a-z_]/, "_")}"

    def render_name(%{resource: resource}), do: inspect(resource)

    def dot_shape(_node), do: "component"
  end
end
