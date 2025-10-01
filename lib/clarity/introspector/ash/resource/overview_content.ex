with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Introspector.Ash.Resource.OverviewContent do
    @moduledoc false

    alias Ash.Resource.Actions
    alias Ash.Resource.Info
    alias Clarity.Vertex.Content

    @spec generate_content(Ash.Resource.t()) :: Content.t()
    def generate_content(resource) do
      %Content{
        id: "#{inspect(resource)}_overview",
        name: "Resource Overview",
        content: {:markdown, fn -> generate_markdown(resource) end}
      }
    end

    @spec generate_markdown(Ash.Resource.t()) :: iodata()
    defp generate_markdown(resource) do
      [
        resource_info_section(resource),
        attributes_section(resource),
        relationships_section(resource),
        actions_section(resource),
        aggregates_section(resource),
        calculations_section(resource)
      ]
    end

    @spec resource_info_section(Ash.Resource.t()) :: iodata()
    defp resource_info_section(resource) do
      domain = Info.domain(resource)

      [
        "## Resource Information\n\n",
        "| Property | Value |\n",
        "| --- | --- |\n",
        "| **Resource** | [",
        inspect(resource),
        "](vertex://resource:",
        inspect(resource),
        ") |\n",
        "| **Domain** | [",
        inspect(domain),
        "](vertex://domain:",
        inspect(domain),
        ") |\n",
        case Info.data_layer(resource) do
          nil ->
            []

          data_layer ->
            [
              "| **Data Layer** | [",
              inspect(data_layer),
              "](vertex://data_layer:",
              inspect(data_layer),
              ") |\n"
            ]
        end,
        case Info.description(resource) do
          nil -> []
          description -> ["| **Description** | ", clean_description(description), " |\n"]
        end,
        "\n\n"
      ]
    end

    @spec attributes_section(Ash.Resource.t()) :: iodata()
    defp attributes_section(resource) do
      attributes = Info.attributes(resource)

      if Enum.empty?(attributes) do
        []
      else
        [
          "## Attributes\n\n",
          "| Name | Type | Description | Primary Key | Allow Nil | Public |\n",
          "| --- | --- | --- | --- | --- | --- |\n",
          attributes
          |> Enum.map(&attribute_row(&1, resource))
          |> Enum.intersperse(""),
          "\n\n"
        ]
      end
    end

    @spec attribute_row(Ash.Resource.Attribute.t(), Ash.Resource.t()) :: iodata()
    defp attribute_row(attribute, resource) do
      description = clean_description(attribute.description)
      type_display = format_type_with_link(attribute.type)

      [
        "| [",
        Atom.to_string(attribute.name),
        "](vertex://attribute:",
        inspect(resource),
        ":",
        Atom.to_string(attribute.name),
        ")",
        " | ",
        type_display,
        " | ",
        description,
        " | ",
        to_string(attribute.primary_key?),
        " | ",
        to_string(attribute.allow_nil?),
        " | ",
        to_string(attribute.public?),
        " |\n"
      ]
    end

    @spec relationships_section(Ash.Resource.t()) :: iodata()
    defp relationships_section(resource) do
      relationships = Info.relationships(resource)

      if Enum.empty?(relationships) do
        []
      else
        [
          "## Relationships\n\n",
          "| Name | Type | Destination | Description |\n",
          "| --- | --- | --- | --- |\n",
          relationships
          |> Enum.map(&relationship_row(&1, resource))
          |> Enum.intersperse(""),
          "\n\n"
        ]
      end
    end

    @spec relationship_row(Ash.Resource.Relationships.relationship(), Ash.Resource.t()) ::
            iodata()
    defp relationship_row(relationship, resource) do
      description = clean_description(relationship.description)
      destination = relationship.destination

      [
        "| [",
        Atom.to_string(relationship.name),
        "](vertex://relationship:",
        inspect(resource),
        ":",
        Atom.to_string(relationship.name),
        ")",
        " | `",
        Atom.to_string(relationship.type),
        "`",
        " | [",
        inspect(destination),
        "](vertex://resource:",
        inspect(destination),
        ")",
        " | ",
        description,
        " |\n"
      ]
    end

    @spec actions_section(Ash.Resource.t()) :: iodata()
    defp actions_section(resource) do
      actions = Info.actions(resource)

      if Enum.empty?(actions) do
        []
      else
        grouped_actions = Enum.group_by(actions, & &1.type)

        [
          "## Actions\n\n",
          grouped_actions
          |> Enum.map(&action_group_section(&1, resource))
          |> Enum.intersperse("\n"),
          "\n\n"
        ]
      end
    end

    @spec action_group_section({atom(), [Actions.action()]}, Ash.Resource.t()) :: iodata()
    defp action_group_section({type, actions}, resource) do
      [
        "### ",
        String.capitalize(to_string(type)),
        " Actions\n\n",
        "| Name | Description | Primary |\n",
        "| --- | --- | --- |\n",
        actions
        |> Enum.map(&action_row(&1, resource))
        |> Enum.intersperse(""),
        "\n"
      ]
    end

    @spec action_row(Actions.action(), Ash.Resource.t()) :: iodata()
    defp action_row(action, resource) do
      description = clean_description(action.description)

      [
        "| [",
        Atom.to_string(action.name),
        "](vertex://action:",
        inspect(resource),
        ":",
        Atom.to_string(action.name),
        ")",
        " | ",
        description,
        " | ",
        to_string(action.primary?),
        " |\n"
      ]
    end

    @spec aggregates_section(Ash.Resource.t()) :: iodata()
    defp aggregates_section(resource) do
      aggregates = Info.aggregates(resource)

      if Enum.empty?(aggregates) do
        []
      else
        [
          "## Aggregates\n\n",
          "| Name | Type | Field | Relationship |\n",
          "| --- | --- | --- | --- |\n",
          aggregates
          |> Enum.map(&aggregate_row(&1, resource))
          |> Enum.intersperse(""),
          "\n\n"
        ]
      end
    end

    @spec aggregate_row(Ash.Resource.Aggregate.t(), Ash.Resource.t()) :: iodata()
    defp aggregate_row(aggregate, resource) do
      field_display =
        case aggregate.field do
          nil -> ""
          field -> ["`", to_string(field), "`"]
        end

      [
        "| [",
        Atom.to_string(aggregate.name),
        "](vertex://aggregate:",
        inspect(resource),
        ":",
        Atom.to_string(aggregate.name),
        ")",
        " | `",
        Atom.to_string(aggregate.kind),
        "`",
        " | ",
        field_display,
        " | `",
        inspect(aggregate.relationship_path),
        "`",
        " |\n"
      ]
    end

    @spec calculations_section(Ash.Resource.t()) :: iodata()
    defp calculations_section(resource) do
      calculations = Info.calculations(resource)

      if Enum.empty?(calculations) do
        []
      else
        [
          "## Calculations\n\n",
          "| Name | Type | Description |\n",
          "| --- | --- | --- |\n",
          calculations
          |> Enum.map(&calculation_row(&1, resource))
          |> Enum.intersperse(""),
          "\n\n"
        ]
      end
    end

    @spec calculation_row(Ash.Resource.Calculation.t(), Ash.Resource.t()) :: iodata()
    defp calculation_row(calculation, resource) do
      description = clean_description(calculation.description)
      type_display = format_type_with_link(calculation.type)

      [
        "| [",
        Atom.to_string(calculation.name),
        "](vertex://calculation:",
        inspect(resource),
        ":",
        Atom.to_string(calculation.name),
        ")",
        " | ",
        type_display,
        " | ",
        description,
        " |\n"
      ]
    end

    @spec format_type_with_link({:array, any()} | atom() | any()) :: iodata()
    defp format_type_with_link({:array, inner_type}) do
      ["list of ", format_type_with_link(inner_type)]
    end

    defp format_type_with_link(type) when is_atom(type) do
      type_name =
        type
        |> to_string()
        |> String.replace_prefix("Elixir.", "")
        |> String.replace_prefix("Ash.Type.", "")

      ["[", type_name, "](vertex://type:", inspect(type), ")"]
    end

    defp format_type_with_link(type) do
      type_name = inspect(type)
      ["[", type_name, "](vertex://type:", type_name, ")"]
    end

    @spec clean_description(String.t() | nil | any()) :: String.t()
    defp clean_description(nil), do: ""

    defp clean_description(description) when is_binary(description) do
      description
      |> String.trim()
      |> String.replace("\n", " ")
      |> String.replace(~r/\s+/, " ")
    end

    defp clean_description(_), do: ""
  end
end
