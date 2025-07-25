defmodule AshAtlas.Vertex.Relationship do
  @type t() :: %__MODULE__{
          relationship: Ash.Resource.Relationships.relationship(),
          resource: Ash.Resource.t()
        }
  @enforce_keys [:relationship, :resource]
  defstruct [:relationship, :resource]

  defimpl AshAtlas.Vertex do
    def unique_id(%{relationship: %{name: name}, resource: resource}),
      do: "relationship:#{inspect(resource)}:#{name}"

    def graph_id(%{relationship: %{name: name}, resource: resource}),
      do: [inspect(resource), "_", Atom.to_string(name)]

    def graph_group(%{resource: resource}),
      do: [inspect(resource), inspect(Ash.Resource.Relationships)]

    def type_label(%{relationship: %mod{}}), do: inspect(mod)
    def render_name(%{relationship: %{name: name}}), do: Atom.to_string(name)
    def dot_shape(_vertex), do: "rarrow"
  end
end
