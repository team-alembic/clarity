with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Vertex.Ash.Aggregate do
    @moduledoc """
    Vertex implementation for Ash resource aggregates.
    """
    alias Ash.Resource.Aggregate
    alias Clarity.SourceLocation

    @type t() :: %__MODULE__{
            aggregate: Aggregate.t(),
            resource: Ash.Resource.t()
          }
    @enforce_keys [:aggregate, :resource]
    defstruct [:aggregate, :resource]

    defimpl Clarity.Vertex do
      alias Clarity.Vertex.Util

      @impl Clarity.Vertex
      def id(%@for{aggregate: %{name: name}, resource: resource}),
        do: Util.id(@for, [resource, name])

      @impl Clarity.Vertex
      def type_label(_vertex), do: inspect(Aggregate)

      @impl Clarity.Vertex
      def name(%@for{aggregate: %{name: name}}), do: Atom.to_string(name)
    end

    defimpl Clarity.Vertex.GraphGroupProvider do
      @impl Clarity.Vertex.GraphGroupProvider
      def graph_group(%@for{resource: resource}), do: [inspect(resource), inspect(Aggregate)]
    end

    defimpl Clarity.Vertex.GraphShapeProvider do
      @impl Clarity.Vertex.GraphShapeProvider
      def shape(_vertex), do: "Mdiamond"
    end

    defimpl Clarity.Vertex.SourceLocationProvider do
      @impl Clarity.Vertex.SourceLocationProvider
      def source_location(%@for{aggregate: aggregate, resource: resource}) do
        SourceLocation.from_spark_entity(resource, aggregate)
      end
    end
  end
end
