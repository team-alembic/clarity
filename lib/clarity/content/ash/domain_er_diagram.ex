with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Content.Ash.DomainErDiagram do
    @moduledoc """
    D2 entity-relationship diagram for an Ash domain.

    Renders every resource in the domain as a `sql_table` with its
    attributes, then draws relationship edges between tables. Resources
    reachable from outside the domain (relationship destinations that are
    not members of the domain) are still rendered as tables but in a
    dimmed style.
    """

    @behaviour Clarity.Content

    alias Ash.Domain.Info, as: DomainInfo
    alias Ash.Resource.Info, as: ResourceInfo
    alias Clarity.Content.D2.Helpers
    alias Clarity.Vertex.Ash.Domain
    alias Clarity.Vertex.Ash.Resource

    @impl Clarity.Content
    def name, do: "ER Diagram"

    @impl Clarity.Content
    def description, do: "Entity-relationship diagram for all resources in this domain"

    @impl Clarity.Content
    def sort_priority, do: -80

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
        Enum.map(resources, &resource_table(&1, false)),
        Enum.map(external_destinations, &resource_table(&1, true)),
        Enum.map(relationships, &relationship_edge/1)
      ]
    end

    @spec resource_table(Ash.Resource.t(), boolean()) :: iodata()
    defp resource_table(resource, external?) do
      id = Helpers.safe_id(inspect(resource))

      [
        id,
        ": ",
        Helpers.quoted(Helpers.short_name(resource)),
        " {\n",
        "  shape: sql_table\n",
        "  link: \"",
        Helpers.vertex_link(Resource, [resource]),
        "\"\n",
        if external? do
          "  style: { opacity: 0.6; stroke-dash: 4 }\n"
        else
          []
        end,
        Enum.map(ResourceInfo.attributes(resource), &attribute_row/1),
        "}\n"
      ]
    end

    @spec attribute_row(Ash.Resource.Attribute.t()) :: iodata()
    defp attribute_row(attribute) do
      label =
        attribute.name
        |> Atom.to_string()
        |> then(&if(attribute.primary_key?, do: "* " <> &1, else: &1))

      [
        "  ",
        Helpers.quoted(label),
        ": ",
        Helpers.quoted(format_type(attribute.type)),
        "\n"
      ]
    end

    @spec relationship_edge({Ash.Resource.t(), Ash.Resource.Relationships.relationship()}) ::
            iodata()
    defp relationship_edge({source, relationship}) do
      src = Helpers.safe_id(inspect(source))
      dst = Helpers.safe_id(inspect(relationship.destination))

      label =
        IO.iodata_to_binary([
          Atom.to_string(relationship.type),
          " ",
          Atom.to_string(relationship.name)
        ])

      [src, " -> ", dst, ": ", Helpers.quoted(label), "\n"]
    end

    @spec format_type(term()) :: String.t()
    defp format_type({:array, inner}), do: "list of " <> format_type(inner)

    defp format_type(type) when is_atom(type) do
      type
      |> to_string()
      |> String.replace_prefix("Elixir.", "")
      |> String.replace_prefix("Ash.Type.", "")
    end

    defp format_type(type), do: inspect(type)
  end
end
