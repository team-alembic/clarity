with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Vertex.Ash.Relationship do
    @moduledoc """
    Vertex implementation for Ash resource relationships.
    """
    alias Ash.Resource.Relationships
    alias Clarity.SourceLocation

    @type t() :: %__MODULE__{
            relationship: Relationships.relationship(),
            resource: Ash.Resource.t()
          }
    @enforce_keys [:relationship, :resource]
    defstruct [:relationship, :resource]

    defimpl Clarity.Vertex do
      alias Clarity.Vertex.Util

      @impl Clarity.Vertex
      def id(%@for{relationship: %{name: name}, resource: resource}),
        do: Util.id(@for, [resource, name])

      @impl Clarity.Vertex
      def type_label(%@for{relationship: %mod{}}), do: inspect(mod)

      @impl Clarity.Vertex
      def name(%@for{relationship: %{name: name}}), do: Atom.to_string(name)
    end

    defimpl Clarity.Vertex.GraphGroupProvider do
      @impl Clarity.Vertex.GraphGroupProvider
      def graph_group(%@for{resource: resource}), do: [inspect(resource), inspect(Relationships)]
    end

    defimpl Clarity.Vertex.GraphShapeProvider do
      @impl Clarity.Vertex.GraphShapeProvider
      def shape(_vertex), do: "rarrow"
    end

    defimpl Clarity.Vertex.SourceLocationProvider do
      @impl Clarity.Vertex.SourceLocationProvider
      def source_location(%@for{relationship: relationship, resource: resource}) do
        SourceLocation.from_spark_entity(resource, relationship)
      end
    end
  end
end
