with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Content.Ash.ResourceClassDiagram do
    @moduledoc """
    D2 UML class diagram for an Ash resource.

    Renders the focused resource as a `class` shape listing every
    attribute with type (visibility `+` for public, `-` for private),
    calculations and aggregates as derived "methods" prefixed with
    `~` (computed), and actions as methods grouped under their type.

    Each related resource is rendered as a neighbouring class shape
    with edges labelled by relationship type and cardinality, so the
    diagram doubles as a structural map.
    """

    @behaviour Clarity.Content

    alias Ash.Resource.Attribute
    alias Ash.Resource.Info
    alias Ash.Resource.Relationships
    alias Clarity.Content.D2.Helpers
    alias Clarity.Vertex.Ash.Resource

    @impl Clarity.Content
    def name, do: "Class Diagram"

    @impl Clarity.Content
    def description, do: "UML class diagram for this resource and its neighbours"

    @impl Clarity.Content
    def sort_priority, do: -75

    @impl Clarity.Content
    def applies?(%Resource{}, _lens), do: true
    def applies?(_vertex, _lens), do: false

    @impl Clarity.Content
    def render_static(%Resource{resource: resource}, _lens) do
      {:d2, fn _props -> to_d2(resource) end}
    end

    @spec to_d2(Ash.Resource.t()) :: iodata()
    defp to_d2(resource) do
      relationships = Info.relationships(resource)
      neighbours = relationships |> Enum.map(& &1.destination) |> Enum.uniq()

      [
        "direction: right\n",
        focused_class(resource),
        Enum.map(neighbours, &neighbour_class/1),
        Enum.map(relationships, &relationship_edge(resource, &1))
      ]
    end

    @spec focused_class(Ash.Resource.t()) :: iodata()
    defp focused_class(resource) do
      id = Helpers.safe_id(inspect(resource))

      [
        id,
        ": ",
        Helpers.quoted(Helpers.short_name(resource)),
        " {\n",
        "  shape: class\n",
        "  link: \"",
        Helpers.vertex_link(Resource, [resource]),
        "\"\n",
        "  style: { stroke-width: 3 }\n",
        Enum.map(Info.attributes(resource), &attribute_field/1),
        Enum.map(Info.calculations(resource), &calculation_field/1),
        Enum.map(Info.aggregates(resource), &aggregate_field/1),
        Enum.map(Info.actions(resource), &action_method/1),
        "}\n"
      ]
    end

    @spec neighbour_class(Ash.Resource.t()) :: iodata()
    defp neighbour_class(resource) do
      id = Helpers.safe_id(inspect(resource))

      [
        id,
        ": ",
        Helpers.quoted(Helpers.short_name(resource)),
        " {\n",
        "  shape: class\n",
        "  link: \"",
        Helpers.vertex_link(Resource, [resource]),
        "\"\n",
        "  style: { opacity: 0.7 }\n",
        Enum.map(Info.attributes(resource), &attribute_field(&1, primary_only: true)),
        "}\n"
      ]
    end

    @spec attribute_field(Attribute.t()) :: iodata()
    @spec attribute_field(Attribute.t(), keyword()) :: iodata()
    defp attribute_field(attribute, opts \\ []) do
      if Keyword.get(opts, :primary_only, false) and not attribute.primary_key?,
        do: [],
        else: do_attribute_field(attribute)
    end

    @spec do_attribute_field(Attribute.t()) :: iodata()
    defp do_attribute_field(attribute) do
      visibility = if attribute.public?, do: "+", else: "-"
      key_marker = if attribute.primary_key?, do: "* ", else: ""
      label = key_marker <> visibility <> Atom.to_string(attribute.name)

      [
        "  ",
        Helpers.quoted(label),
        ": ",
        Helpers.quoted(format_type(attribute.type)),
        "\n"
      ]
    end

    @spec calculation_field(Ash.Resource.Calculation.t()) :: iodata()
    defp calculation_field(calculation) do
      [
        "  ",
        Helpers.quoted("~" <> Atom.to_string(calculation.name) <> "()"),
        ": ",
        Helpers.quoted(format_type(calculation.type)),
        "\n"
      ]
    end

    @spec aggregate_field(Ash.Resource.Aggregate.t()) :: iodata()
    defp aggregate_field(aggregate) do
      [
        "  ",
        Helpers.quoted("Σ" <> Atom.to_string(aggregate.name) <> "()"),
        ": ",
        Helpers.quoted(Atom.to_string(aggregate.kind)),
        "\n"
      ]
    end

    @spec action_method(struct()) :: iodata()
    defp action_method(action) do
      [
        "  ",
        Helpers.quoted(Atom.to_string(action.name) <> "()"),
        ": ",
        Helpers.quoted(Atom.to_string(action.type)),
        "\n"
      ]
    end

    @spec relationship_edge(Ash.Resource.t(), Relationships.relationship()) :: iodata()
    defp relationship_edge(source, relationship) do
      src = Helpers.safe_id(inspect(source))
      dst = Helpers.safe_id(inspect(relationship.destination))

      cardinality =
        case relationship.type do
          :belongs_to -> "1"
          :has_one -> "1"
          :has_many -> "*"
          :many_to_many -> "*"
        end

      label =
        IO.iodata_to_binary([
          Atom.to_string(relationship.type),
          " ",
          Atom.to_string(relationship.name),
          " (",
          cardinality,
          ")"
        ])

      [src, " -> ", dst, ": ", Helpers.quoted(label), "\n"]
    end

    @spec format_type(term()) :: String.t()
    defp format_type({:array, inner}), do: "[" <> format_type(inner) <> "]"

    defp format_type(type) when is_atom(type) do
      type
      |> to_string()
      |> String.replace_prefix("Elixir.", "")
      |> String.replace_prefix("Ash.Type.", "")
    end

    defp format_type(type), do: inspect(type)
  end
end
