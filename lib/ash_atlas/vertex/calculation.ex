defmodule AshAtlas.Vertex.Calculation do
  @moduledoc false
  alias Ash.Resource.Calculation

  @type t() :: %__MODULE__{
          calculation: Calculation.t(),
          resource: Ash.Resource.t()
        }
  @enforce_keys [:calculation, :resource]
  defstruct [:calculation, :resource]

  defimpl AshAtlas.Vertex do
    @impl AshAtlas.Vertex
    def unique_id(%{calculation: %{name: name}, resource: resource}),
      do: "calculation:#{inspect(resource)}:#{name}"

    @impl AshAtlas.Vertex
    def graph_id(%{calculation: %{name: name}, resource: resource}),
      do: [inspect(resource), "_", Atom.to_string(name)]

    @impl AshAtlas.Vertex
    def graph_group(%{resource: resource}), do: [inspect(resource), inspect(Calculation)]

    @impl AshAtlas.Vertex
    def type_label(_vertex), do: inspect(Calculation)

    @impl AshAtlas.Vertex
    def render_name(%{calculation: %{name: name}}), do: Atom.to_string(name)

    @impl AshAtlas.Vertex
    def dot_shape(_vertex), do: "promoter"
  end
end
