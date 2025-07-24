defmodule AshAtlas.Tree.Node.Relationship do
  @type t() :: %__MODULE__{
          relationship: Ash.Resource.Relationships.relationship(),
          resource: Ash.Resource.t()
        }
  @enforce_keys [:relationship, :resource]
  defstruct [:relationship, :resource]

  defimpl AshAtlas.Tree.Node do
    def unique_id(%{relationship: %{name: name}, resource: resource}),
      do: "relationship:#{inspect(resource)}:#{name}"

    def graph_id(%{relationship: %{name: name}, resource: resource}),
      do:
        "relationship_#{resource |> Macro.underscore() |> String.replace(~r/[^a-z_]/, "_")}_#{name}"

    def render_name(%{relationship: %{name: name}}), do: Atom.to_string(name)

    def dot_shape(_node), do: "rarrow"
  end
end
