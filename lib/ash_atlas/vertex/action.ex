defmodule AshAtlas.Vertex.Action do
  @type t() :: %__MODULE__{
          action: Ash.Resource.Actions.action(),
          resource: Ash.Resource.t()
        }
  @enforce_keys [:action, :resource]
  defstruct [:action, :resource]

  defimpl AshAtlas.Vertex do
    def unique_id(%{action: %{name: name}, resource: resource}),
      do: "action:#{inspect(resource)}:#{name}"

    def graph_id(%{action: %{name: name}, resource: resource}),
      do: [inspect(resource), "_", Atom.to_string(name)]

    def graph_group(%{resource: resource}), do: [inspect(resource), inspect(Ash.Resource.Actions)]
    def type_label(%{action: %mod{}}), do: inspect(mod)
    @spec render_name(AshAtlas.Vertex.Action.t()) :: <<_::24, _::_*8>>
    def render_name(%{action: %{name: name}}), do: Atom.to_string(name)
    def dot_shape(_vertex), do: "cds"
  end
end
