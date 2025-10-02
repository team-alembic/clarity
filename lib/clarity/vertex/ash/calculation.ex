with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Vertex.Ash.Calculation do
    @moduledoc """
    Vertex implementation for Ash resource calculations.
    """
    alias Ash.Resource.Calculation
    alias Clarity.SourceLocation

    @type t() :: %__MODULE__{
            calculation: Calculation.t(),
            resource: Ash.Resource.t()
          }
    @enforce_keys [:calculation, :resource]
    defstruct [:calculation, :resource]

    defimpl Clarity.Vertex do
      alias Clarity.Vertex.Util

      @impl Clarity.Vertex
      def id(%@for{calculation: %{name: name}, resource: resource}),
        do: Util.id(@for, [resource, name])

      @impl Clarity.Vertex
      def type_label(_vertex), do: inspect(Calculation)

      @impl Clarity.Vertex
      def name(%@for{calculation: %{name: name}}), do: Atom.to_string(name)
    end

    defimpl Clarity.Vertex.GraphGroupProvider do
      @impl Clarity.Vertex.GraphGroupProvider
      def graph_group(%@for{resource: resource}), do: [inspect(resource), inspect(Calculation)]
    end

    defimpl Clarity.Vertex.GraphShapeProvider do
      @impl Clarity.Vertex.GraphShapeProvider
      def shape(_vertex), do: "promoter"
    end

    defimpl Clarity.Vertex.SourceLocationProvider do
      @impl Clarity.Vertex.SourceLocationProvider
      def source_location(%@for{calculation: calculation, resource: resource}) do
        SourceLocation.from_spark_entity(resource, calculation)
      end
    end

    defimpl Clarity.Vertex.TooltipProvider do
      @impl Clarity.Vertex.TooltipProvider
      def tooltip(vertex),
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
end
