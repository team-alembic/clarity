defmodule AshAtlas.Tree.Node.Calculation do
  @type t() :: %__MODULE__{
          calculation: Ash.Resource.Calculation.t(),
          resource: Ash.Resource.t()
        }
  @enforce_keys [:calculation, :resource]
  defstruct [:calculation, :resource]

  defimpl AshAtlas.Tree.Node do
    def unique_id(%{calculation: %{name: name}, resource: resource}),
      do: "calculation:#{inspect(resource)}:#{name}"

    def graph_id(%{calculation: %{name: name}, resource: resource}),
      do: [inspect(resource), "_", Atom.to_string(name)]

    def graph_group(%{resource: resource}), do: [inspect(resource), inspect(Ash.Resource.Calculation)]
    def type_label(_node), do: inspect(Ash.Resource.Calculation)
    def render_name(%{calculation: %{name: name}}), do: Atom.to_string(name)
    def dot_shape(_node), do: "promoter"
  end
end
