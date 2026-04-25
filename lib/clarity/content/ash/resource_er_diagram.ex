with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Content.Ash.ResourceErDiagram do
    @moduledoc """
    D2 entity-relationship diagram for an Ash resource.

    Renders the focused resource as a `sql_table` showing every attribute
    (with `*` markers for primary keys) plus one `sql_table` per related
    resource and edges labelled with the relationship type.

    Each table title links to its Clarity vertex so the diagram doubles as
    navigation.
    """

    @behaviour Clarity.Content

    alias Ash.Resource.Info
    alias Ash.Resource.Relationships
    alias Clarity.Content.D2.Helpers
    alias Clarity.Vertex.Ash.Resource

    @impl Clarity.Content
    def name, do: "ER Diagram"

    @impl Clarity.Content
    def description, do: "Entity-relationship diagram for this resource and its neighbours"

    @impl Clarity.Content
    def sort_priority, do: -80

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
      neighbour_modules = relationships |> Enum.map(& &1.destination) |> Enum.uniq()
      tables = [resource | neighbour_modules]

      [
        "direction: right\n",
        Enum.map(tables, &resource_table(&1, &1 == resource)),
        Enum.map(relationships, &relationship_edge(resource, &1))
      ]
    end

    @spec resource_table(Ash.Resource.t(), boolean()) :: iodata()
    defp resource_table(resource, focus?) do
      id = Helpers.safe_id(inspect(resource))
      title = Helpers.short_name(resource)

      [
        id,
        ": ",
        Helpers.quoted(title),
        " {\n",
        "  shape: sql_table\n",
        "  link: \"",
        Helpers.vertex_link(Resource, [resource]),
        "\"\n",
        if focus? do
          "  style: { stroke-width: 3 }\n"
        else
          []
        end,
        Enum.map(Info.attributes(resource), &attribute_row/1),
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

    @spec relationship_edge(Ash.Resource.t(), Relationships.relationship()) ::
            iodata()
    defp relationship_edge(source, relationship) do
      src = Helpers.safe_id(inspect(source))
      dst = Helpers.safe_id(inspect(relationship.destination))
      label = relationship_label(relationship)

      [src, " -> ", dst, ": ", Helpers.quoted(label), "\n"]
    end

    @spec relationship_label(Relationships.relationship()) :: String.t()
    defp relationship_label(relationship) do
      IO.iodata_to_binary([
        Atom.to_string(relationship.type),
        " ",
        Atom.to_string(relationship.name)
      ])
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
