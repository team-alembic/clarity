with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Content.Ash.DomainClassDiagram do
    @moduledoc """
    D2 UML class diagram for an Ash domain.

    Renders every resource in the domain as a D2 `class` shape with its
    attributes (visibility-prefixed), calculations and aggregates as
    derived fields, and actions as methods. Cross-resource relationships
    become edges with cardinality. Resources outside the domain that are
    targeted by a relationship are still drawn but in a dimmed style.
    """

    @behaviour Clarity.Content

    alias Ash.Domain.Info, as: DomainInfo
    alias Ash.Resource.Info, as: ResourceInfo
    alias Clarity.Content.D2.Helpers
    alias Clarity.Vertex.Ash.Domain
    alias Clarity.Vertex.Ash.Resource

    @impl Clarity.Content
    def name, do: "Class Diagram"

    @impl Clarity.Content
    def description, do: "UML class diagram for all resources in this domain"

    @impl Clarity.Content
    def sort_priority, do: -75

    @impl Clarity.Content
    def applies?(%Domain{domain: domain}, _lens) do
      DomainInfo.resources(domain) != []
    end

    def applies?(_vertex, _lens), do: false

    @impl Clarity.Content
    def render_static(%Domain{domain: domain}, _lens) do
      {:d2, fn _props -> to_d2(domain) end}
    end

    @spec to_d2(module()) :: iodata()
    defp to_d2(domain) do
      resources = DomainInfo.resources(domain)
      resource_set = MapSet.new(resources)

      relationships =
        Enum.flat_map(resources, fn resource ->
          Enum.map(ResourceInfo.relationships(resource), &{resource, &1})
        end)

      external_destinations =
        relationships
        |> Enum.map(fn {_src, rel} -> rel.destination end)
        |> Enum.reject(&MapSet.member?(resource_set, &1))
        |> Enum.uniq()

      [
        "direction: right\n",
        Enum.map(resources, &resource_class(&1, false)),
        Enum.map(external_destinations, &resource_class(&1, true)),
        Enum.map(relationships, &relationship_edge/1)
      ]
    end

    @spec resource_class(Ash.Resource.t(), boolean()) :: iodata()
    defp resource_class(resource, external?) do
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
        if external? do
          "  style: { opacity: 0.6; stroke-dash: 4 }\n"
        else
          []
        end,
        Enum.map(ResourceInfo.attributes(resource), &attribute_field(&1, external?)),
        if external? do
          []
        else
          [
            Enum.map(ResourceInfo.calculations(resource), &calculation_field/1),
            Enum.map(ResourceInfo.aggregates(resource), &aggregate_field/1)
          ]
        end,
        "}\n"
      ]
    end

    @spec attribute_field(Ash.Resource.Attribute.t(), boolean()) :: iodata()
    defp attribute_field(attribute, external?) do
      if external? and not attribute.primary_key? do
        []
      else
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

    @spec relationship_edge({Ash.Resource.t(), Ash.Resource.Relationships.relationship()}) ::
            iodata()
    defp relationship_edge({source, relationship}) do
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
