defmodule AshAtlas.Vertex.Aggregate do
  @moduledoc false
  alias Ash.Resource.Aggregate

  @type t() :: %__MODULE__{
          aggregate: Aggregate.t(),
          resource: Ash.Resource.t()
        }
  @enforce_keys [:aggregate, :resource]
  defstruct [:aggregate, :resource]

  defimpl AshAtlas.Vertex do
    @impl AshAtlas.Vertex
    def unique_id(%{aggregate: %{name: name}, resource: resource}),
      do: "aggregate:#{inspect(resource)}:#{name}"

    @impl AshAtlas.Vertex
    def graph_id(%{aggregate: %{name: name}, resource: resource}),
      do: [inspect(resource), "_", Atom.to_string(name)]

    @impl AshAtlas.Vertex
    def graph_group(%{resource: resource}), do: [inspect(resource), inspect(Aggregate)]

    @impl AshAtlas.Vertex
    def type_label(_vertex), do: inspect(Aggregate)

    @impl AshAtlas.Vertex
    def render_name(%{aggregate: %{name: name}}), do: Atom.to_string(name)

    @impl AshAtlas.Vertex
    def dot_shape(_vertex), do: "Mdiamond"

    @impl AshAtlas.Vertex
    def markdown_overview(_vertex), do: []
  end
end
