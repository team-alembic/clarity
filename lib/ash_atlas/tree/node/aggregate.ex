defmodule AshAtlas.Tree.Node.Aggregate do
  @type t() :: %__MODULE__{
          aggregate: Ash.Resource.Aggregate.t(),
          resource: Ash.Resource.t()
        }
  @enforce_keys [:aggregate, :resource]
  defstruct [:aggregate, :resource]

  defimpl AshAtlas.Tree.Node do
    def unique_id(%{aggregate: %{name: name}, resource: resource}),
      do: "aggregate:#{inspect(resource)}:#{name}"

    def graph_id(%{aggregate: %{name: name}, resource: resource}),
      do: [inspect(resource), "_", Atom.to_string(name)]

    def graph_group(%{resource: resource}), do: [ inspect(resource), inspect(Ash.Resource.Aggregate)]
    def type_label(_node), do: inspect(Ash.Resource.Aggregate)
    def render_name(%{aggregate: %{name: name}}), do: Atom.to_string(name)
    def dot_shape(_node), do: "Mdiamond"
  end
end
