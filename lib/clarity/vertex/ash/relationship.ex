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
      @impl Clarity.Vertex
      def unique_id(%{relationship: %{name: name}, resource: resource}),
        do: "relationship:#{inspect(resource)}:#{name}"

      @impl Clarity.Vertex
      def graph_id(%{relationship: %{name: name}, resource: resource}),
        do: [inspect(resource), "_", Atom.to_string(name)]

      @impl Clarity.Vertex
      def graph_group(%{resource: resource}), do: [inspect(resource), inspect(Relationships)]

      @impl Clarity.Vertex
      def type_label(%{relationship: %mod{}}), do: inspect(mod)

      @impl Clarity.Vertex
      def render_name(%{relationship: %{name: name}}), do: Atom.to_string(name)

      @impl Clarity.Vertex
      def dot_shape(_vertex), do: "rarrow"

      @impl Clarity.Vertex
      def markdown_overview(_vertex), do: []

      @impl Clarity.Vertex
      def source_location(%{relationship: relationship, resource: resource}) do
        SourceLocation.from_spark_entity(resource, relationship)
      end
    end
  end
end
