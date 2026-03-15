with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Content.Ash.AggregateOverview do
    @moduledoc """
    Content provider for Ash Aggregate overview.

    Displays comprehensive information about an Ash aggregate including its kind,
    target, filters, and configuration.
    """

    @behaviour Clarity.Content

    alias Clarity.Vertex.Ash.Aggregate
    alias Clarity.Vertex.Ash.Attribute
    alias Clarity.Vertex.Ash.Relationship
    alias Clarity.Vertex.Ash.Resource
    alias Clarity.Vertex.Ash.Type
    alias Clarity.Vertex.Util

    @impl Clarity.Content
    def name, do: "Aggregate Overview"

    @impl Clarity.Content
    def description, do: "Overview of this Ash aggregate"

    @impl Clarity.Content
    def sort_priority, do: -100

    @impl Clarity.Content
    def applies?(%Aggregate{}, _lens), do: true
    def applies?(_vertex, _lens), do: false

    @impl Clarity.Content
    def render_static(%Aggregate{aggregate: aggregate, resource: resource}, _lens) do
      {:markdown, fn _props -> generate_markdown(aggregate, resource) end}
    end

    @spec generate_markdown(Ash.Resource.Aggregate.t(), Ash.Resource.t()) :: iodata()
    defp generate_markdown(aggregate, resource) do
      [
        aggregate_header(aggregate),
        aggregate_info_section(aggregate, resource),
        configuration_section(aggregate),
        target_section(aggregate, resource),
        filter_section(aggregate),
        join_filters_section(aggregate, resource),
        sort_section(aggregate),
        constraints_section(aggregate)
      ]
    end

    @spec aggregate_header(Ash.Resource.Aggregate.t()) :: iodata()
    defp aggregate_header(aggregate) do
      kind_badge = String.upcase(to_string(aggregate.kind))

      [
        "# ",
        Atom.to_string(aggregate.name),
        "\n\n",
        "**Kind:** `",
        kind_badge,
        "`\n\n"
      ]
    end

    @spec aggregate_info_section(Ash.Resource.Aggregate.t(), Ash.Resource.t()) :: iodata()
    defp aggregate_info_section(aggregate, resource) do
      [
        "## Aggregate Information\n\n",
        "| Property | Value |\n",
        "| --- | --- |\n",
        "| **Name** | `",
        Atom.to_string(aggregate.name),
        "` |\n",
        "| **Kind** | `",
        Atom.to_string(aggregate.kind),
        "` |\n",
        "| **Resource** | [",
        inspect(resource),
        "](vertex://",
        Util.id(Resource, [resource]),
        ") |\n",
        "| **Return Type** | ",
        format_type_with_link(aggregate.type),
        " |\n",
        case aggregate.description do
          nil -> []
          "" -> []
          description -> ["| **Description** | ", clean_description(description), " |\n"]
        end,
        "\n\n"
      ]
    end

    @spec configuration_section(Ash.Resource.Aggregate.t()) :: iodata()
    defp configuration_section(aggregate) do
      [
        "## Configuration\n\n",
        "| Setting | Value |\n",
        "| --- | --- |\n",
        "| **Public** | ",
        format_boolean(aggregate.public?),
        " |\n",
        "| **Sensitive** | ",
        format_boolean(aggregate.sensitive?),
        " |\n",
        "| **Filterable** | ",
        format_filterable(aggregate.filterable?),
        " |\n",
        "| **Sortable** | ",
        format_boolean(aggregate.sortable?),
        " |\n",
        "| **Include Nil** | ",
        format_boolean(Map.get(aggregate, :include_nil?, false)),
        " |\n",
        "| **Unique** | ",
        format_boolean(Map.get(aggregate, :uniq?, false)),
        " |\n",
        "| **Authorize** | ",
        format_boolean(Map.get(aggregate, :authorize?, true)),
        " |\n",
        case aggregate.default do
          nil ->
            []

          default ->
            [
              "| **Default Value** | `",
              inspect(default),
              "` |\n"
            ]
        end,
        "\n\n"
      ]
    end

    @spec format_filterable(boolean()) :: String.t()
    defp format_filterable(false), do: "No"
    defp format_filterable(_), do: "Yes"

    @spec target_section(Ash.Resource.Aggregate.t(), Ash.Resource.t()) :: iodata()
    defp target_section(aggregate, resource) do
      related? = Map.get(aggregate, :related?, true)

      [
        "## Target\n\n",
        "| Property | Value |\n",
        "| --- | --- |\n",
        if related? do
          [
            "| **Relationship Path** | ",
            format_relationship_path(aggregate.relationship_path, resource),
            " |\n"
          ]
        else
          []
        end,
        case aggregate.field do
          nil ->
            []

          field ->
            [
              "| **Aggregated Field** | ",
              format_field_link(field, aggregate.relationship_path, resource, related?),
              " |\n"
            ]
        end,
        case Map.get(aggregate, :read_action) do
          nil -> []
          action -> ["| **Read Action** | `", to_string(action), "` |\n"]
        end,
        case Map.get(aggregate, :implementation) do
          nil -> []
          impl -> ["| **Custom Implementation** | `", inspect(impl), "` |\n"]
        end,
        "\n\n"
      ]
    end

    @spec format_relationship_path(list(atom()), Ash.Resource.t()) :: iodata()
    defp format_relationship_path(path, resource) when is_list(path) do
      Enum.map_intersperse(path, " → ", fn rel_name ->
        [
          "[`",
          to_string(rel_name),
          "`](vertex://",
          Util.id(Relationship, [resource, rel_name]),
          ")"
        ]
      end)
    end

    @spec format_field_link(atom(), list(atom()), Ash.Resource.t(), boolean()) :: iodata()
    defp format_field_link(field, _relationship_path, resource, true = _related?) do
      [
        "[`",
        to_string(field),
        "`](vertex://",
        Util.id(Attribute, [resource, field]),
        ")"
      ]
    end

    defp format_field_link(field, _relationship_path, _resource, false = _related?) do
      ["`", to_string(field), "`"]
    end

    @spec filter_section(Ash.Resource.Aggregate.t()) :: iodata()
    defp filter_section(aggregate) do
      case aggregate.filter do
        [] ->
          []

        filter ->
          [
            "## Filter\n\n",
            "This aggregate applies the following filter:\n\n",
            "```elixir\n",
            inspect(filter, pretty: true),
            "\n```\n\n"
          ]
      end
    end

    @spec join_filters_section(Ash.Resource.Aggregate.t(), Ash.Resource.t()) :: iodata()
    defp join_filters_section(aggregate, resource) do
      join_filters = Map.get(aggregate, :join_filters, [])

      if Enum.empty?(join_filters) do
        []
      else
        [
          "## Join Filters\n\n",
          "| Relationship Path | Filter |\n",
          "| --- | --- |\n",
          Enum.map_intersperse(join_filters, "", &join_filter_row(&1, resource)),
          "\n\n"
        ]
      end
    end

    @spec join_filter_row(%Ash.Resource.Aggregate.JoinFilter{}, Ash.Resource.t()) :: iodata()
    defp join_filter_row(join_filter, resource) do
      path = Map.get(join_filter, :relationship_path, [])
      filter = Map.get(join_filter, :filter, [])

      [
        "| ",
        format_relationship_path(path, resource),
        " | `",
        inspect(filter),
        "` |\n"
      ]
    end

    @spec sort_section(Ash.Resource.Aggregate.t()) :: iodata()
    defp sort_section(aggregate) do
      sort = aggregate.sort

      if is_nil(sort) or sort == [] do
        []
      else
        [
          "## Sort\n\n",
          "Results are sorted by:\n\n",
          "```elixir\n",
          inspect(sort, pretty: true),
          "\n```\n\n"
        ]
      end
    end

    @spec constraints_section(Ash.Resource.Aggregate.t()) :: iodata()
    defp constraints_section(aggregate) do
      constraints = aggregate.constraints || []

      if Enum.empty?(constraints) do
        []
      else
        [
          "## Return Type Constraints\n\n",
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

    @spec clean_description(String.t()) :: String.t()
    defp clean_description(description) when is_binary(description) do
      description
      |> String.trim()
      |> String.replace("\n", " ")
      |> String.replace(~r/\s+/, " ")
    end
  end
end
