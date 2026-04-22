with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Content.Ash.AttributeOverview do
    @moduledoc """
    Content provider for Ash Attribute overview.

    Displays comprehensive information about an Ash attribute including its type,
    characteristics, constraints, and default values.
    """

    @behaviour Clarity.Content

    alias Clarity.Vertex.Ash.Attribute
    alias Clarity.Vertex.Ash.Resource
    alias Clarity.Vertex.Ash.Type
    alias Clarity.Vertex.Util

    @impl Clarity.Content
    def name, do: "Attribute Overview"

    @impl Clarity.Content
    def description, do: "Overview of this Ash attribute"

    @impl Clarity.Content
    def sort_priority, do: -100

    @impl Clarity.Content
    def applies?(%Attribute{}, _lens), do: true
    def applies?(_vertex, _lens), do: false

    @impl Clarity.Content
    def render_static(%Attribute{attribute: attribute, resource: resource}, _lens) do
      {:markdown, fn _props -> generate_markdown(attribute, resource) end}
    end

    @spec generate_markdown(Ash.Resource.Attribute.t(), Ash.Resource.t()) :: iodata()
    defp generate_markdown(attribute, resource) do
      [
        attribute_header(attribute),
        attribute_info_section(attribute, resource),
        characteristics_section(attribute),
        constraints_section(attribute),
        defaults_section(attribute),
        data_layer_section(attribute)
      ]
    end

    @spec attribute_header(Ash.Resource.Attribute.t()) :: iodata()
    defp attribute_header(attribute) do
      [
        "# ",
        Atom.to_string(attribute.name),
        "\n\n",
        "**Type:** ",
        format_type_with_link(attribute.type),
        "\n\n"
      ]
    end

    @spec attribute_info_section(Ash.Resource.Attribute.t(), Ash.Resource.t()) :: iodata()
    defp attribute_info_section(attribute, resource) do
      [
        "## Attribute Information\n\n",
        "| Property | Value |\n",
        "| --- | --- |\n",
        "| **Name** | `",
        Atom.to_string(attribute.name),
        "` |\n",
        "| **Type** | ",
        format_type_with_link(attribute.type),
        " |\n",
        "| **Resource** | [",
        inspect(resource),
        "](vertex://",
        Util.id(Resource, [resource]),
        ") |\n",
        case attribute.description do
          nil -> []
          "" -> []
          description -> ["| **Description** | ", clean_description(description), " |\n"]
        end,
        "\n\n"
      ]
    end

    @spec characteristics_section(Ash.Resource.Attribute.t()) :: iodata()
    defp characteristics_section(attribute) do
      [
        "## Characteristics\n\n",
        "| Characteristic | Value |\n",
        "| --- | --- |\n",
        "| **Primary Key** | ",
        format_boolean(attribute.primary_key?),
        " |\n",
        "| **Allow Nil** | ",
        format_boolean(attribute.allow_nil?),
        " |\n",
        "| **Public** | ",
        format_boolean(attribute.public?),
        " |\n",
        "| **Writable** | ",
        format_boolean(attribute.writable?),
        " |\n",
        "| **Generated** | ",
        format_boolean(attribute.generated?),
        " |\n",
        "| **Sensitive** | ",
        format_boolean(attribute.sensitive?),
        " |\n",
        "| **Filterable** | ",
        format_boolean(attribute.filterable?),
        " |\n",
        "| **Sortable** | ",
        format_boolean(attribute.sortable?),
        " |\n",
        "| **Always Select** | ",
        format_boolean(attribute.always_select?),
        " |\n",
        "| **Select By Default** | ",
        format_boolean(attribute.select_by_default?),
        " |\n",
        "\n\n"
      ]
    end

    @spec constraints_section(Ash.Resource.Attribute.t()) :: iodata()
    defp constraints_section(attribute) do
      constraints = attribute.constraints

      if Enum.empty?(constraints) do
        []
      else
        [
          "## Constraints\n\n",
          "| Constraint | Value |\n",
          "| --- | --- |\n",
          Enum.map_intersperse(constraints, "", &constraint_row/1),
          "\n\n"
        ]
      end
    end

    @spec constraint_row({atom(), term()}) :: iodata()
    defp constraint_row({key, value}) do
      [
        "| `",
        to_string(key),
        "` | `",
        inspect(value),
        "` |\n"
      ]
    end

    @spec defaults_section(Ash.Resource.Attribute.t()) :: iodata()
    defp defaults_section(attribute) do
      items = [
        default_config(attribute),
        update_default_config(attribute),
        match_other_defaults_config(attribute)
      ]

      items = Enum.reject(items, &is_nil/1)

      if Enum.empty?(items) do
        []
      else
        [
          "## Default Values\n\n",
          "| Setting | Value |\n",
          "| --- | --- |\n",
          Enum.map(items, fn {label, value} ->
            ["| **", label, "** | ", value, " |\n"]
          end),
          "\n\n"
        ]
      end
    end

    @spec default_config(Ash.Resource.Attribute.t()) :: {String.t(), iodata()} | nil
    defp default_config(%{default: default}) when not is_nil(default) do
      {"Default", format_default_value(default)}
    end

    defp default_config(_), do: nil

    @spec update_default_config(Ash.Resource.Attribute.t()) :: {String.t(), iodata()} | nil
    defp update_default_config(%{update_default: update_default})
         when not is_nil(update_default) do
      {"Update Default", format_default_value(update_default)}
    end

    defp update_default_config(_), do: nil

    @spec match_other_defaults_config(Ash.Resource.Attribute.t()) ::
            {String.t(), String.t()} | nil
    defp match_other_defaults_config(%{match_other_defaults?: true}) do
      {"Match Other Defaults", "Yes"}
    end

    defp match_other_defaults_config(_), do: nil

    @spec format_default_value(term()) :: iodata()
    defp format_default_value(value) when is_function(value) do
      "Function"
    end

    defp format_default_value({mod, fun, args}) when is_atom(mod) and is_atom(fun) do
      arity = length(args)
      ["MFA: `", inspect(mod), ".", to_string(fun), "/", to_string(arity), "`"]
    end

    defp format_default_value(value) do
      ["`", inspect(value), "`"]
    end

    @spec data_layer_section(Ash.Resource.Attribute.t()) :: iodata()
    defp data_layer_section(attribute) do
      source = attribute.source

      if is_nil(source) or source == attribute.name do
        []
      else
        [
          "## Data Layer\n\n",
          "| Property | Value |\n",
          "| --- | --- |\n",
          "| **Source Field** | `",
          to_string(source),
          "` |\n",
          "\n\n"
        ]
      end
    end

    @spec format_type_with_link(module() | {:array, atom}) :: iodata()
    defp format_type_with_link({:array, inner_type}) do
      ["list of ", format_type_with_link(inner_type)]
    end

    defp format_type_with_link(type) when is_atom(type) do
      type_name =
        type
        |> to_string()
        |> String.replace_prefix("Elixir.", "")
        |> String.replace_prefix("Ash.Type.", "")

      ["[", type_name, "](vertex://", Util.id(Type, [type]), ")"]
    end

    defp format_type_with_link(type) do
      type_name = inspect(type)
      ["[", type_name, "](vertex://", Util.id(Type, [type]), ")"]
    end

    @spec format_boolean(boolean()) :: String.t()
    defp format_boolean(true), do: "Yes"
    defp format_boolean(false), do: "No"
    defp format_boolean(_), do: "No"

    @spec clean_description(String.t() | nil) :: String.t()
    defp clean_description(nil), do: ""

    defp clean_description(description) when is_binary(description) do
      description
      |> String.trim()
      |> String.replace("\n", " ")
      |> String.replace(~r/\s+/, " ")
    end
  end
end
