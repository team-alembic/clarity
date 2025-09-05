defmodule Atlas.Vertex.Calculation do
  @moduledoc false
  alias Ash.Resource.Calculation

  @type t() :: %__MODULE__{
          calculation: Calculation.t(),
          resource: Ash.Resource.t()
        }
  @enforce_keys [:calculation, :resource]
  defstruct [:calculation, :resource]

  defimpl Atlas.Vertex do
    @impl Atlas.Vertex
    def unique_id(%{calculation: %{name: name}, resource: resource}),
      do: "calculation:#{inspect(resource)}:#{name}"

    @impl Atlas.Vertex
    def graph_id(%{calculation: %{name: name}, resource: resource}),
      do: [inspect(resource), "_", Atom.to_string(name)]

    @impl Atlas.Vertex
    def graph_group(%{resource: resource}), do: [inspect(resource), inspect(Calculation)]

    @impl Atlas.Vertex
    def type_label(_vertex), do: inspect(Calculation)

    @impl Atlas.Vertex
    def render_name(%{calculation: %{name: name}}), do: Atom.to_string(name)

    @impl Atlas.Vertex
    def dot_shape(_vertex), do: "promoter"

    @impl Atlas.Vertex
    def markdown_overview(vertex),
      do: [
        "Attribute: `",
        inspect(vertex.calculation.name),
        "` on Resource: `",
        inspect(vertex.resource),
        "`\n\n",
        if vertex.calculation.description do
          [vertex.calculation.description, "\n\n"]
        else
          []
        end,
        "* Type: `",
        inspect(vertex.calculation.type),
        "`\n",
        " * Public: `",
        inspect(vertex.calculation.public?),
        "`\n"
      ]
  end
end
