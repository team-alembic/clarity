with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Content.Ash.RelationshipOverview do
    @moduledoc """
    Content provider for Ash Relationship overview.

    Displays comprehensive information about an Ash relationship including its type,
    source and destination configuration, and relationship-specific options.
    """

    @behaviour Clarity.Content

    alias Ash.Resource.Relationships
    alias Clarity.Vertex.Ash.Relationship
    alias Clarity.Vertex.Ash.Resource
    alias Clarity.Vertex.Util

    @impl Clarity.Content
    def name, do: "Relationship Overview"

    @impl Clarity.Content
    def description, do: "Overview of this Ash relationship"

    @impl Clarity.Content
    def applies?(%Relationship{}, _lens), do: true
    def applies?(_vertex, _lens), do: false

    @impl Clarity.Content
    def render_static(%Relationship{relationship: relationship, resource: resource}, _lens) do
      {:markdown, fn _props -> generate_markdown(relationship, resource) end}
    end

    @spec generate_markdown(Relationships.relationship(), Ash.Resource.t()) ::
            iodata()
    defp generate_markdown(relationship, resource) do
      [
        relationship_header(relationship),
        relationship_info_section(relationship, resource),
        characteristics_section(relationship),
        source_destination_section(relationship),
        type_specific_section(relationship)
      ]
    end

    @spec relationship_header(Relationships.relationship()) :: iodata()
    defp relationship_header(relationship) do
      type_badge = String.upcase(to_string(relationship.type))

      [
        "# ",
        Atom.to_string(relationship.name),
        "\n\n",
        "**Type:** `",
        type_badge,
        "`\n\n"
      ]
    end

    @dialyzer {:nowarn_function, relationship_info_section: 2}
    @spec relationship_info_section(Relationships.relationship(), Ash.Resource.t()) ::
            iodata()
    defp relationship_info_section(relationship, resource) do
      [
        "## Relationship Information\n\n",
        "| Property | Value |\n",
        "| --- | --- |\n",
        "| **Name** | `",
        Atom.to_string(relationship.name),
        "` |\n",
        "| **Type** | `",
        Atom.to_string(relationship.type),
        "` |\n",
        "| **Cardinality** | `",
        Atom.to_string(relationship.cardinality),
        "` |\n",
        "| **Source Resource** | [",
        inspect(resource),
        "](vertex://",
        Util.id(Resource, [resource]),
        ") |\n",
        "| **Destination Resource** | [",
        inspect(relationship.destination),
        "](vertex://",
        Util.id(Resource, [relationship.destination]),
        ") |\n",
        case relationship.description do
          nil -> []
          "" -> []
          description -> ["| **Description** | ", clean_description(description), " |\n"]
        end,
        "\n\n"
      ]
    end

    @spec characteristics_section(Relationships.relationship()) :: iodata()
    defp characteristics_section(relationship) do
      [
        "## Characteristics\n\n",
        "| Characteristic | Value |\n",
        "| --- | --- |\n",
        "| **Public** | ",
        format_boolean(relationship.public?),
        " |\n",
        "| **Writable** | ",
        format_boolean(Map.get(relationship, :writable?, true)),
        " |\n",
        "| **Filterable** | ",
        format_boolean(Map.get(relationship, :filterable?, true)),
        " |\n",
        "| **Sortable** | ",
        format_boolean(Map.get(relationship, :sortable?, true)),
        " |\n",
        "\n\n"
      ]
    end

    @spec source_destination_section(Relationships.relationship()) :: iodata()
    defp source_destination_section(relationship) do
      [
        "## Source & Destination Configuration\n\n",
        "| Property | Value |\n",
        "| --- | --- |\n",
        "| **Source Attribute** | `",
        to_string(relationship.source_attribute),
        "` |\n",
        "| **Destination Attribute** | `",
        to_string(relationship.destination_attribute),
        "` |\n",
        case Map.get(relationship, :read_action) do
          nil -> []
          action -> ["| **Read Action** | `", to_string(action), "` |\n"]
        end,
        case Map.get(relationship, :filter) do
          nil -> []
          _filter -> ["| **Has Filter** | Yes |\n"]
        end,
        case Map.get(relationship, :sort) do
          nil -> []
          sort -> ["| **Sort** | `", inspect(sort), "` |\n"]
        end,
        "\n\n"
      ]
    end

    @spec type_specific_section(Relationships.relationship()) :: iodata()
    defp type_specific_section(relationship) do
      case relationship.type do
        :belongs_to -> belongs_to_section(relationship)
        :many_to_many -> many_to_many_section(relationship)
        :has_many -> has_many_section(relationship)
        :has_one -> has_one_section(relationship)
      end
    end

    @spec belongs_to_section(Relationships.relationship()) :: iodata()
    defp belongs_to_section(relationship) do
      items = [
        allow_nil_config(relationship),
        primary_key_config(relationship),
        define_attribute_config(relationship),
        attribute_type_config(relationship),
        attribute_writable_config(relationship)
      ]

      items = Enum.reject(items, &is_nil/1)

      if Enum.empty?(items) do
        []
      else
        [
          "## BelongsTo-Specific Configuration\n\n",
          "| Setting | Value |\n",
          "| --- | --- |\n",
          Enum.map(items, fn {label, value} ->
            ["| **", label, "** | ", value, " |\n"]
          end),
          "\n\n"
        ]
      end
    end

    @spec allow_nil_config(Relationships.relationship()) ::
            {String.t(), String.t()} | nil
    defp allow_nil_config(%{allow_nil?: allow_nil?}) when not is_nil(allow_nil?) do
      {"Allow Nil", format_boolean(allow_nil?)}
    end

    defp allow_nil_config(_), do: nil

    @spec primary_key_config(Relationships.relationship()) ::
            {String.t(), String.t()} | nil
    defp primary_key_config(%{primary_key?: true}), do: {"Primary Key", "Yes"}
    defp primary_key_config(_), do: nil

    @spec define_attribute_config(Relationships.relationship()) ::
            {String.t(), String.t()} | nil
    defp define_attribute_config(%{define_attribute?: define?}) when not is_nil(define?) do
      {"Define Attribute", format_boolean(define?)}
    end

    defp define_attribute_config(_), do: nil

    @spec attribute_type_config(Relationships.relationship()) ::
            {String.t(), iodata()} | nil
    defp attribute_type_config(%{attribute_type: type}) when not is_nil(type) do
      {"Attribute Type", ["`", inspect(type), "`"]}
    end

    defp attribute_type_config(_), do: nil

    @spec attribute_writable_config(Relationships.relationship()) ::
            {String.t(), String.t()} | nil
    defp attribute_writable_config(%{attribute_writable?: writable?})
         when not is_nil(writable?) do
      {"Attribute Writable", format_boolean(writable?)}
    end

    defp attribute_writable_config(_), do: nil

    @spec many_to_many_section(Relationships.relationship()) :: iodata()
    defp many_to_many_section(relationship) do
      items = [
        through_config(relationship),
        source_attribute_on_join_config(relationship),
        destination_attribute_on_join_config(relationship)
      ]

      items = Enum.reject(items, &is_nil/1)

      if Enum.empty?(items) do
        []
      else
        [
          "## ManyToMany-Specific Configuration\n\n",
          "| Setting | Value |\n",
          "| --- | --- |\n",
          Enum.map(items, fn {label, value} ->
            ["| **", label, "** | ", value, " |\n"]
          end),
          "\n\n"
        ]
      end
    end

    @spec through_config(Relationships.relationship()) ::
            {String.t(), iodata()} | nil
    defp through_config(%{through: through}) when not is_nil(through) do
      {"Through Resource",
       ["[", inspect(through), "](vertex://", Util.id(Resource, [through]), ")"]}
    end

    defp through_config(_), do: nil

    @spec source_attribute_on_join_config(Relationships.relationship()) ::
            {String.t(), iodata()} | nil
    defp source_attribute_on_join_config(%{source_attribute_on_join_resource: attr})
         when not is_nil(attr) do
      {"Source Attribute on Join", ["`", to_string(attr), "`"]}
    end

    defp source_attribute_on_join_config(_), do: nil

    @spec destination_attribute_on_join_config(Relationships.relationship()) ::
            {String.t(), iodata()} | nil
    defp destination_attribute_on_join_config(%{destination_attribute_on_join_resource: attr})
         when not is_nil(attr) do
      {"Destination Attribute on Join", ["`", to_string(attr), "`"]}
    end

    defp destination_attribute_on_join_config(_), do: nil

    @spec has_many_section(Relationships.relationship()) :: iodata()
    defp has_many_section(relationship) do
      items = [
        limit_config(relationship),
        could_be_related_config(relationship),
        no_attributes_config(relationship)
      ]

      items = Enum.reject(items, &is_nil/1)

      if Enum.empty?(items) do
        []
      else
        [
          "## HasMany-Specific Configuration\n\n",
          "| Setting | Value |\n",
          "| --- | --- |\n",
          Enum.map(items, fn {label, value} ->
            ["| **", label, "** | ", value, " |\n"]
          end),
          "\n\n"
        ]
      end
    end

    @spec limit_config(Relationships.relationship()) :: {String.t(), String.t()} | nil
    defp limit_config(%{limit: limit}) when not is_nil(limit) do
      {"Limit", to_string(limit)}
    end

    defp limit_config(_), do: nil

    @spec could_be_related_config(Relationships.relationship()) ::
            {String.t(), String.t()} | nil
    defp could_be_related_config(%{could_be_related_at_creation?: true}) do
      {"Could Be Related at Creation", "Yes"}
    end

    defp could_be_related_config(_), do: nil

    @spec no_attributes_config(Relationships.relationship()) ::
            {String.t(), String.t()} | nil
    defp no_attributes_config(%{no_attributes?: true}) do
      {"No Attributes", "Yes (advanced)"}
    end

    defp no_attributes_config(_), do: nil

    @spec has_one_section(Relationships.relationship()) :: iodata()
    defp has_one_section(_relationship), do: []

    @spec format_boolean(boolean()) :: String.t()
    defp format_boolean(true), do: "Yes"
    defp format_boolean(false), do: "No"
    defp format_boolean(_), do: "No"

    @spec clean_description(String.t()) :: String.t()
    defp clean_description(description) when is_binary(description) do
      description
      |> String.trim()
      |> String.replace("\n", " ")
      |> String.replace(~r/\s+/, " ")
    end
  end
end
