defmodule AshAtlas.Vertex.Relationship do
  @moduledoc false
  alias Ash.Resource.Relationships

  @type t() :: %__MODULE__{
          relationship: Relationships.relationship(),
          resource: Ash.Resource.t()
        }
  @enforce_keys [:relationship, :resource]
  defstruct [:relationship, :resource]

  defimpl AshAtlas.Vertex do
    @impl AshAtlas.Vertex
    def unique_id(%{relationship: %{name: name}, resource: resource}),
      do: "relationship:#{inspect(resource)}:#{name}"

    @impl AshAtlas.Vertex
    def graph_id(%{relationship: %{name: name}, resource: resource}),
      do: [inspect(resource), "_", Atom.to_string(name)]

    @impl AshAtlas.Vertex
    def graph_group(%{resource: resource}), do: [inspect(resource), inspect(Relationships)]

    @impl AshAtlas.Vertex
    def type_label(%{relationship: %mod{}}), do: inspect(mod)

    @impl AshAtlas.Vertex
    def render_name(%{relationship: %{name: name}}), do: Atom.to_string(name)

    @impl AshAtlas.Vertex
    def dot_shape(_vertex), do: "rarrow"

    @impl AshAtlas.Vertex
    def markdown_overview(_vertex), do: []
  end
end
