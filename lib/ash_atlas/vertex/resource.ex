defmodule AshAtlas.Vertex.Resource do
  @moduledoc false
  @type t() :: %__MODULE__{
          resource: Ash.Resource.t()
        }
  @enforce_keys [:resource]
  defstruct [:resource]

  defimpl AshAtlas.Vertex do
    @impl AshAtlas.Vertex
    def unique_id(%{resource: resource}), do: "resource:#{inspect(resource)}"

    @impl AshAtlas.Vertex
    def graph_id(%{resource: resource}), do: inspect(resource)

    @impl AshAtlas.Vertex
    def graph_group(%{resource: resource}), do: [inspect(resource)]

    @impl AshAtlas.Vertex
    def type_label(_vertex), do: inspect(Ash.Resource)

    @impl AshAtlas.Vertex
    def render_name(%{resource: resource}), do: inspect(resource)

    @impl AshAtlas.Vertex
    def dot_shape(_vertex), do: "component"
  end
end
