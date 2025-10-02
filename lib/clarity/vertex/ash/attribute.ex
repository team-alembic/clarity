with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Vertex.Ash.Attribute do
    @moduledoc """
    Vertex implementation for Ash resource attributes.
    """
    alias Ash.Resource.Attribute
    alias Clarity.SourceLocation

    @type t() :: %__MODULE__{
            attribute: Attribute.t(),
            resource: Ash.Resource.t()
          }
    @enforce_keys [:attribute, :resource]
    defstruct [:attribute, :resource]

    defimpl Clarity.Vertex do
      alias Clarity.Vertex.Util

      @impl Clarity.Vertex
      def id(%@for{attribute: %{name: name}, resource: resource}),
        do: Util.id(@for, [resource, name])

      @impl Clarity.Vertex
      def type_label(_vertex), do: inspect(Attribute)

      @impl Clarity.Vertex
      def name(%@for{attribute: %{name: name}}), do: Atom.to_string(name)
    end

    defimpl Clarity.Vertex.GraphGroupProvider do
      @impl Clarity.Vertex.GraphGroupProvider
      def graph_group(%@for{resource: resource}), do: [inspect(resource), inspect(Attribute)]
    end

    defimpl Clarity.Vertex.GraphShapeProvider do
      @impl Clarity.Vertex.GraphShapeProvider
      def shape(_vertex), do: "rectangle"
    end

    defimpl Clarity.Vertex.SourceLocationProvider do
      @impl Clarity.Vertex.SourceLocationProvider
      def source_location(%@for{attribute: attribute, resource: resource}) do
        SourceLocation.from_spark_entity(resource, attribute)
      end
    end

    defimpl Clarity.Vertex.TooltipProvider do
      @impl Clarity.Vertex.TooltipProvider
      def tooltip(vertex),
        do: [
          "Attribute: `",
          inspect(vertex.attribute.name),
          "` on Resource: `",
          inspect(vertex.resource),
          "`\n\n",
          if vertex.attribute.description do
            [vertex.attribute.description, "\n\n"]
          else
            []
          end,
          "* Type: `",
          inspect(vertex.attribute.type),
          "`\n",
          " * Public: `",
          inspect(vertex.attribute.public?),
          "`\n"
        ]
    end
  end
end
