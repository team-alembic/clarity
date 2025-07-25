defmodule AshAtlas.Tree.Node.Resource do
  @type t() :: %__MODULE__{
          resource: Ash.Resource.t()
        }
  @enforce_keys [:resource]
  defstruct [:resource]

  defimpl AshAtlas.Tree.Node do
    def unique_id(%{resource: resource}), do: "resource:#{inspect(resource)}"
    def graph_id(%{resource: resource}), do: inspect(resource)
    def graph_group(_node), do: []
    def type_label(_node), do: inspect(Ash.Resource)
    def render_name(%{resource: resource}), do: inspect(resource)
    def dot_shape(_node), do: "component"
  end
end
