defmodule Atlas.Vertex.Relationship do
  @moduledoc false
  alias Ash.Resource.Relationships

  @type t() :: %__MODULE__{
          relationship: Relationships.relationship(),
          resource: Ash.Resource.t()
        }
  @enforce_keys [:relationship, :resource]
  defstruct [:relationship, :resource]

  defimpl Atlas.Vertex do
    @impl Atlas.Vertex
    def unique_id(%{relationship: %{name: name}, resource: resource}),
      do: "relationship:#{inspect(resource)}:#{name}"

    @impl Atlas.Vertex
    def graph_id(%{relationship: %{name: name}, resource: resource}),
      do: [inspect(resource), "_", Atom.to_string(name)]

    @impl Atlas.Vertex
    def graph_group(%{resource: resource}), do: [inspect(resource), inspect(Relationships)]

    @impl Atlas.Vertex
    def type_label(%{relationship: %mod{}}), do: inspect(mod)

    @impl Atlas.Vertex
    def render_name(%{relationship: %{name: name}}), do: Atom.to_string(name)

    @impl Atlas.Vertex
    def dot_shape(_vertex), do: "rarrow"

    @impl Atlas.Vertex
    def markdown_overview(_vertex), do: []
  end
end
