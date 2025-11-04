with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Content.Ash.CalculationOverview do
    @moduledoc """
    Content provider for Ash Calculation overview.

    Displays comprehensive information about an Ash calculation including its type,
    implementation, arguments, and dependencies.
    """

    @behaviour Clarity.Content

    alias Clarity.Vertex.Ash.Calculation
    alias Clarity.Vertex.Ash.Resource
    alias Clarity.Vertex.Ash.Type
    alias Clarity.Vertex.Util

    @impl Clarity.Content
    def name, do: "Calculation Overview"

    @impl Clarity.Content
    def description, do: "Overview of this Ash calculation"

    @impl Clarity.Content
    def applies?(%Calculation{}, _lens), do: true
    def applies?(_vertex, _lens), do: false

    @impl Clarity.Content
    def render_static(%Calculation{calculation: calculation, resource: resource}, _lens) do
      {:markdown, fn _props -> generate_markdown(calculation, resource) end}
    end

    @spec generate_markdown(Ash.Resource.Calculation.t(), Ash.Resource.t()) :: iodata()
    defp generate_markdown(calculation, resource) do
      [
        calculation_header(calculation),
        calculation_info_section(calculation, resource),
        configuration_section(calculation),
        implementation_section(calculation),
        arguments_section(calculation),
        dependencies_section(calculation),
        constraints_section(calculation)
      ]
    end

    @spec calculation_header(Ash.Resource.Calculation.t()) :: iodata()
    defp calculation_header(calculation) do
      [
        "# ",
        Atom.to_string(calculation.name),
        "\n\n",
        "**Type:** ",
        format_type_with_link(calculation.type),
        "\n\n"
      ]
    end

    @spec calculation_info_section(Ash.Resource.Calculation.t(), Ash.Resource.t()) :: iodata()
    defp calculation_info_section(calculation, resource) do
      [
        "## Calculation Information\n\n",
        "| Property | Value |\n",
        "| --- | --- |\n",
        "| **Name** | `",
        Atom.to_string(calculation.name),
        "` |\n",
        "| **Type** | ",
        format_type_with_link(calculation.type),
        " |\n",
        "| **Resource** | [",
        inspect(resource),
        "](vertex://",
        Util.id(Resource, [resource]),
        ") |\n",
        case calculation.description do
          nil -> []
          "" -> []
          description -> ["| **Description** | ", clean_description(description), " |\n"]
        end,
        "\n\n"
      ]
    end

    @spec configuration_section(Ash.Resource.Calculation.t()) :: iodata()
    defp configuration_section(calculation) do
      [
        "## Configuration\n\n",
        "| Setting | Value |\n",
        "| --- | --- |\n",
        "| **Public** | ",
        format_boolean(calculation.public?),
        " |\n",
        "| **Sensitive** | ",
        format_boolean(calculation.sensitive?),
        " |\n",
        "| **Filterable** | ",
        format_filterable(calculation.filterable?),
        " |\n",
        "| **Sortable** | ",
        format_boolean(calculation.sortable?),
        " |\n",
        "| **Allow Nil** | ",
        format_boolean(calculation.allow_nil?),
        " |\n",
        "| **Async** | ",
        format_boolean(Map.get(calculation, :async?, false)),
        " |\n",
        "\n\n"
      ]
    end

    @spec format_filterable(boolean()) :: String.t()
    defp format_filterable(false), do: "No"
    defp format_filterable(_), do: "Yes"

    @spec implementation_section(Ash.Resource.Calculation.t()) :: iodata()
    defp implementation_section(calculation) do
      impl_type = determine_implementation_type(calculation.calculation)
      {impl_summary, impl_detail} = format_implementation(calculation.calculation)

      [
        "## Implementation\n\n",
        "| Property | Value |\n",
        "| --- | --- |\n",
        "| **Type** | ",
        impl_type,
        " |\n",
        "| **Module** | ",
        impl_summary,
        " |\n",
        "\n",
        case impl_detail do
          nil -> []
          detail -> ["\n**Options:**\n\n```elixir\n", detail, "\n```\n"]
        end,
        "\n\n"
      ]
    end

    @spec determine_implementation_type(module() | {module(), keyword()}) :: String.t()
    defp determine_implementation_type({module, _opts}) when is_atom(module) do
      "Module-based"
    end

    defp determine_implementation_type(module) when is_atom(module) do
      "Module-based"
    end

    @spec format_implementation(module() | {module(), keyword()}) :: {iodata(), String.t() | nil}
    defp format_implementation({module, opts}) when is_atom(module) do
      summary = ["`", inspect(module), "`"]
      detail = if Enum.empty?(opts), do: nil, else: inspect(opts, pretty: true)
      {summary, detail}
    end

    defp format_implementation(module) when is_atom(module) do
      {["`", inspect(module), "`"], nil}
    end

    @spec arguments_section(Ash.Resource.Calculation.t()) :: iodata()
    defp arguments_section(calculation) do
      arguments = calculation.arguments

      if Enum.empty?(arguments) do
        []
      else
        [
          "## Arguments\n\n",
          "| Name | Type | Description | Required | Default |\n",
          "| --- | --- | --- | --- | --- |\n",
          arguments
          |> Enum.map(&argument_row/1)
          |> Enum.intersperse(""),
          "\n\n"
        ]
      end
    end

    @spec argument_row(Ash.Resource.Calculation.Argument.t()) :: iodata()
    defp argument_row(argument) do
      description = clean_description(Map.get(argument, :description))
      type_display = format_type_with_link(argument.type)
      required = !argument.allow_nil?
      default = format_default(Map.get(argument, :default))

      [
        "| `",
        Atom.to_string(argument.name),
        "` | ",
        type_display,
        " | ",
        description,
        " | ",
        format_boolean(required),
        " | ",
        default,
        " |\n"
      ]
    end

    @spec format_default(term()) :: iodata()
    defp format_default(nil), do: "_None_"

    defp format_default(value) do
      ["`", inspect(value), "`"]
    end

    @spec dependencies_section(Ash.Resource.Calculation.t()) :: iodata()
    defp dependencies_section(calculation) do
      load = calculation.load

      if Enum.empty?(load) do
        []
      else
        [
          "## Dependencies\n\n",
          "This calculation requires the following fields/relationships to be loaded:\n\n",
          load
          |> Enum.map(&format_dependency/1)
          |> Enum.intersperse("\n"),
          "\n\n"
        ]
      end
    end

    @spec format_dependency(atom()) :: iodata()
    defp format_dependency(dep) when is_atom(dep) do
      ["- `", to_string(dep), "`"]
    end

    @spec constraints_section(Ash.Resource.Calculation.t()) :: iodata()
    defp constraints_section(calculation) do
      constraints = calculation.constraints

      if Enum.empty?(constraints) do
        []
      else
        [
          "## Return Type Constraints\n\n",
          "| Constraint | Value |\n",
          "| --- | --- |\n",
          constraints
          |> Enum.map(&constraint_row/1)
          |> Enum.intersperse(""),
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
