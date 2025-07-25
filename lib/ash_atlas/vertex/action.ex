defmodule AshAtlas.Vertex.Action do
  @moduledoc false
  alias Ash.Resource.Actions

  @type t() :: %__MODULE__{
          action: Actions.action(),
          resource: Ash.Resource.t()
        }
  @enforce_keys [:action, :resource]
  defstruct [:action, :resource]

  defimpl AshAtlas.Vertex do
    @impl AshAtlas.Vertex
    def unique_id(%{action: %{name: name}, resource: resource}),
      do: "action:#{inspect(resource)}:#{name}"

    @impl AshAtlas.Vertex
    def graph_id(%{action: %{name: name}, resource: resource}),
      do: [inspect(resource), "_", Atom.to_string(name)]

    @impl AshAtlas.Vertex
    def graph_group(%{resource: resource}), do: [inspect(resource), inspect(Actions)]

    @impl AshAtlas.Vertex
    def type_label(%{action: %mod{}}), do: inspect(mod)

    @impl AshAtlas.Vertex
    def render_name(%{action: %{name: name}}), do: Atom.to_string(name)

    @impl AshAtlas.Vertex
    def dot_shape(_vertex), do: "cds"
  end
end
