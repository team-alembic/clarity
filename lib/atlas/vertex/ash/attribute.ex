with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Atlas.Vertex.Ash.Attribute do
    @moduledoc false
    alias Ash.Resource.Attribute

    @type t() :: %__MODULE__{
            attribute: Attribute.t(),
            resource: Ash.Resource.t()
          }
    @enforce_keys [:attribute, :resource]
    defstruct [:attribute, :resource]

    defimpl Atlas.Vertex do
      @impl Atlas.Vertex
      def unique_id(%{attribute: %{name: name}, resource: resource}),
        do: "attribute:#{inspect(resource)}:#{name}"

      @impl Atlas.Vertex
      def graph_id(%{attribute: %{name: name}, resource: resource}),
        do: [inspect(resource), "_", Atom.to_string(name)]

      @impl Atlas.Vertex
      def graph_group(%{resource: resource}), do: [inspect(resource), inspect(Attribute)]

      @impl Atlas.Vertex
      def type_label(_vertex), do: inspect(Attribute)

      @impl Atlas.Vertex
      def render_name(%{attribute: %{name: name}}), do: Atom.to_string(name)

      @impl Atlas.Vertex
      def dot_shape(_vertex), do: "rectangle"

      @impl Atlas.Vertex
      def markdown_overview(vertex),
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
