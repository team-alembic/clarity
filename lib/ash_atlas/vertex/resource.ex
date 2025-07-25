defmodule AshAtlas.Vertex.Resource do
  @type t() :: %__MODULE__{
          resource: Ash.Resource.t()
        }
  @enforce_keys [:resource]
  defstruct [:resource]

  defimpl AshAtlas.Vertex do
    def unique_id(%{resource: resource}), do: "resource:#{inspect(resource)}"
    def graph_id(%{resource: resource}), do: inspect(resource)
    def graph_group(_vertex), do: []
    def type_label(_vertex), do: inspect(Ash.Resource)
    def render_name(%{resource: resource}), do: inspect(resource)
    def dot_shape(_vertex), do: "component"
  end
end
