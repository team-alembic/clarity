with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Vertex.Ash.Calculation do
    @moduledoc false
    alias Ash.Resource.Calculation
    alias Clarity.SourceLocation

    @type t() :: %__MODULE__{
            calculation: Calculation.t(),
            resource: Ash.Resource.t()
          }
    @enforce_keys [:calculation, :resource]
    defstruct [:calculation, :resource]

    defimpl Clarity.Vertex do
      @impl Clarity.Vertex
      def unique_id(%{calculation: %{name: name}, resource: resource}),
        do: "calculation:#{inspect(resource)}:#{name}"

      @impl Clarity.Vertex
      def graph_id(%{calculation: %{name: name}, resource: resource}),
        do: [inspect(resource), "_", Atom.to_string(name)]

      @impl Clarity.Vertex
      def graph_group(%{resource: resource}), do: [inspect(resource), inspect(Calculation)]

      @impl Clarity.Vertex
      def type_label(_vertex), do: inspect(Calculation)

      @impl Clarity.Vertex
      def render_name(%{calculation: %{name: name}}), do: Atom.to_string(name)

      @impl Clarity.Vertex
      def dot_shape(_vertex), do: "promoter"

      @impl Clarity.Vertex
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

      @impl Clarity.Vertex
      def source_location(%{calculation: calculation, resource: resource}) do
        SourceLocation.from_spark_entity(resource, calculation)
      end
    end
  end
end
