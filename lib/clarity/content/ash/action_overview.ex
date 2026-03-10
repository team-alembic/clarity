with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Content.Ash.ActionOverview do
    @moduledoc """
    Content provider for Ash Action overview.

    Displays comprehensive information about an Ash action including its configuration,
    arguments, changes, validations, and type-specific options.
    """

    @behaviour Clarity.Content

    alias Ash.Resource.Actions
    alias Clarity.Vertex.Ash.Action
    alias Clarity.Vertex.Ash.Resource
    alias Clarity.Vertex.Ash.Type
    alias Clarity.Vertex.Util

    @impl Clarity.Content
    def name, do: "Action Overview"

    @impl Clarity.Content
    def description, do: "Overview of this Ash action"

    @impl Clarity.Content
    def sort_priority, do: -100

    @impl Clarity.Content
    def applies?(%Action{}, _lens), do: true
    def applies?(_vertex, _lens), do: false

    @impl Clarity.Content
    def render_static(%Action{action: action, resource: resource}, _lens) do
      {:markdown, fn _props -> generate_markdown(action, resource) end}
    end

    @spec generate_markdown(Actions.action(), Ash.Resource.t()) :: iodata()
    defp generate_markdown(action, resource) do
      [
        action_header(action),
        action_info_section(action, resource),
        configuration_section(action),
        arguments_section(action),
        changes_section(action),
        type_specific_section(action)
      ]
    end

    @spec action_header(Actions.action()) :: iodata()
    defp action_header(action) do
      type_badge = String.upcase(to_string(action.type))
      primary_badge = if action.primary?, do: " (PRIMARY)", else: ""

      [
        "# ",
        Atom.to_string(action.name),
        "\n\n",
        "**Type:** `",
        type_badge,
        "`",
        primary_badge,
        "\n\n"
      ]
    end

    @spec action_info_section(Actions.action(), Ash.Resource.t()) :: iodata()
    defp action_info_section(action, resource) do
      [
        "## Action Information\n\n",
        "| Property | Value |\n",
        "| --- | --- |\n",
        "| **Name** | `",
        Atom.to_string(action.name),
        "` |\n",
        "| **Type** | `",
        Atom.to_string(action.type),
        "` |\n",
        "| **Resource** | [",
        inspect(resource),
        "](vertex://",
        Util.id(Resource, [resource]),
        ") |\n",
        "| **Primary** | ",
        format_boolean(action.primary?),
        " |\n",
        case action.description do
          nil -> []
          "" -> []
          description -> ["| **Description** | ", clean_description(description), " |\n"]
        end,
        "\n\n"
      ]
    end

    @spec configuration_section(Actions.action()) :: iodata()
    defp configuration_section(action) do
      config_items = [
        {"Transaction", format_boolean(action.transaction?)},
        accept_config(action),
        reject_config(action),
        require_attributes_config(action),
        manual_config(action),
        touches_resources_config(action),
        skip_unknown_inputs_config(action)
      ]

      config_items = Enum.reject(config_items, &is_nil/1)

      if Enum.empty?(config_items) do
        []
      else
        [
          "## Configuration\n\n",
          "| Setting | Value |\n",
          "| --- | --- |\n",
          Enum.map(config_items, fn {label, value} ->
            ["| **", label, "** | ", value, " |\n"]
          end),
          "\n\n"
        ]
      end
    end

    @spec accept_config(Actions.action()) :: {String.t(), iodata()} | nil
    defp accept_config(%{accept: accept}) when is_list(accept) and accept != [] do
      {"Accept", format_atom_list(accept)}
    end

    defp accept_config(_), do: nil

    @spec reject_config(Actions.action()) :: {String.t(), iodata()} | nil
    defp reject_config(%{reject: reject}) when not is_nil(reject) and reject != [] do
      {"Reject", format_atom_list(reject)}
    end

    defp reject_config(_), do: nil

    @spec require_attributes_config(Actions.action()) :: {String.t(), iodata()} | nil
    defp require_attributes_config(%{require_attributes: attrs})
         when not is_nil(attrs) and attrs != [] do
      {"Required Attributes", format_atom_list(attrs)}
    end

    defp require_attributes_config(_), do: nil

    @spec manual_config(Actions.action()) :: {String.t(), iodata()} | nil
    defp manual_config(%{manual: {mod, _opts}}) when is_atom(mod) do
      {"Manual", inspect(mod)}
    end

    defp manual_config(%{manual: mod}) when is_atom(mod) do
      {"Manual", inspect(mod)}
    end

    defp manual_config(_), do: nil

    @spec touches_resources_config(Actions.action()) :: {String.t(), iodata()} | nil
    defp touches_resources_config(%{touches_resources: resources})
         when not is_nil(resources) and resources != [] do
      {"Touches Resources", format_module_list(resources)}
    end

    defp touches_resources_config(_), do: nil

    @spec skip_unknown_inputs_config(Actions.action()) :: {String.t(), iodata()} | nil
    defp skip_unknown_inputs_config(%{skip_unknown_inputs: inputs})
         when not is_nil(inputs) and inputs != [] do
      {"Skip Unknown Inputs", format_atom_list(inputs)}
    end

    defp skip_unknown_inputs_config(_), do: nil

    @spec arguments_section(Actions.action()) :: iodata()
    defp arguments_section(action) do
      if Enum.empty?(action.arguments) do
        []
      else
        [
          "## Arguments\n\n",
          "| Name | Type | Description | Required | Allow Nil |\n",
          "| --- | --- | --- | --- | --- |\n",
          action.arguments
          |> Enum.map(&argument_row/1)
          |> Enum.intersperse(""),
          "\n\n"
        ]
      end
    end

    @spec argument_row(Ash.Resource.Actions.Argument.t()) :: iodata()
    defp argument_row(argument) do
      description = clean_description(argument.description)
      type_display = format_type_with_link(argument.type)
      required = !argument.allow_nil?

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
        format_boolean(argument.allow_nil?),
        " |\n"
      ]
    end

    @spec changes_section(Actions.action()) :: iodata()
    defp changes_section(action) do
      changes = Map.get(action, :changes, [])

      if Enum.empty?(changes) do
        []
      else
        [
          "## Changes\n\n",
          changes
          |> Enum.map(&format_change/1)
          |> Enum.intersperse("\n"),
          "\n\n"
        ]
      end
    end

    @spec format_change(Ash.Resource.Change.t()) :: iodata()
    defp format_change(change) do
      case change do
        {mod, _opts} when is_atom(mod) -> ["- ", inspect(mod)]
        mod when is_atom(mod) -> ["- ", inspect(mod)]
        %{change: {mod, _opts}} when is_atom(mod) -> ["- ", inspect(mod)]
        %{change: mod} when is_atom(mod) -> ["- ", inspect(mod)]
      end
    end

    @spec type_specific_section(Actions.action()) :: iodata()
    defp type_specific_section(action) do
      case action.__struct__ do
        Actions.Create -> create_specific_section(action)
        Actions.Read -> read_specific_section(action)
        Actions.Update -> update_destroy_specific_section(action, "Update")
        Actions.Destroy -> update_destroy_specific_section(action, "Destroy")
        _ -> generic_specific_section(action)
      end
    end

    @spec create_specific_section(Actions.Create.t()) :: iodata()
    defp create_specific_section(action) do
      items = [
        upsert_config(action),
        upsert_identity_config(action),
        upsert_fields_config(action)
      ]

      items = Enum.reject(items, &is_nil/1)

      if Enum.empty?(items) do
        []
      else
        [
          "## Create-Specific Configuration\n\n",
          "| Setting | Value |\n",
          "| --- | --- |\n",
          Enum.map(items, fn {label, value} ->
            ["| **", label, "** | ", value, " |\n"]
          end),
          "\n\n"
        ]
      end
    end

    @spec upsert_config(Actions.Create.t()) :: {String.t(), String.t()} | nil
    defp upsert_config(%{upsert?: true}), do: {"Upsert", "Yes"}
    defp upsert_config(_), do: nil

    @spec upsert_identity_config(Actions.Create.t()) :: {String.t(), iodata()} | nil
    defp upsert_identity_config(%{upsert_identity: identity}) when not is_nil(identity) do
      {"Upsert Identity", "`#{identity}`"}
    end

    defp upsert_identity_config(_), do: nil

    @spec upsert_fields_config(Actions.Create.t()) :: {String.t(), iodata()} | nil
    defp upsert_fields_config(%{upsert_fields: fields}) when not is_nil(fields) do
      case fields do
        :replace_all -> {"Upsert Fields", "Replace all"}
        {:replace, list} -> {"Upsert Fields", "Replace: #{format_atom_list(list)}"}
        list when is_list(list) -> {"Upsert Fields", format_atom_list(list)}
        _ -> nil
      end
    end

    defp upsert_fields_config(_), do: nil

    @spec read_specific_section(Actions.Read.t()) :: iodata()
    defp read_specific_section(action) do
      items = [
        get_config(action),
        get_by_config(action),
        timeout_config(action),
        pagination_config(action)
      ]

      items = Enum.reject(items, &is_nil/1)

      config_section =
        if Enum.empty?(items) do
          []
        else
          [
            "## Read-Specific Configuration\n\n",
            "| Setting | Value |\n",
            "| --- | --- |\n",
            Enum.map(items, fn {label, value} ->
              ["| **", label, "** | ", value, " |\n"]
            end),
            "\n\n"
          ]
        end

      [config_section, preparations_section(action)]
    end

    @spec preparations_section(Actions.Read.t()) :: iodata()
    defp preparations_section(action) do
      preparations = action.preparations

      if Enum.empty?(preparations) do
        []
      else
        [
          "## Preparations\n\n",
          preparations
          |> Enum.map(&format_preparation/1)
          |> Enum.intersperse("\n"),
          "\n\n"
        ]
      end
    end

    @spec format_preparation(Ash.Resource.Preparation.ref() | Ash.Resource.Validation.ref()) ::
            iodata()
    defp format_preparation(preparation) do
      case preparation do
        {mod, _opts} when is_atom(mod) -> ["- ", inspect(mod)]
        mod when is_atom(mod) -> ["- ", inspect(mod)]
        %{preparation: {mod, _opts}} when is_atom(mod) -> ["- ", inspect(mod)]
        %{preparation: mod} when is_atom(mod) -> ["- ", inspect(mod)]
        _ -> ["- Custom preparation"]
      end
    end

    @spec get_config(Actions.Read.t()) :: {String.t(), String.t()} | nil
    defp get_config(%{get?: true}), do: {"Get", "Yes (returns single result)"}
    defp get_config(_), do: nil

    @spec get_by_config(Actions.Read.t()) :: {String.t(), iodata()} | nil
    defp get_by_config(%{get_by: fields}) when not is_nil(fields) and fields != [] do
      {"Get By", format_atom_list(List.wrap(fields))}
    end

    defp get_by_config(_), do: nil

    @spec timeout_config(Actions.Read.t()) :: {String.t(), String.t()} | nil
    defp timeout_config(%{timeout: timeout}) when not is_nil(timeout) do
      {"Timeout", "#{timeout}ms"}
    end

    defp timeout_config(_), do: nil

    @spec pagination_config(Actions.Read.t()) :: {String.t(), String.t()} | nil
    defp pagination_config(%{pagination: pagination}) when not is_nil(pagination) do
      {"Pagination", "Enabled"}
    end

    defp pagination_config(_), do: nil

    @spec update_destroy_specific_section(Actions.Update.t() | Actions.Destroy.t(), String.t()) ::
            iodata()
    defp update_destroy_specific_section(action, type) do
      items = [
        require_atomic_config(action),
        atomic_upgrade_config(action),
        atomic_upgrade_with_config(action)
      ]

      items = Enum.reject(items, &is_nil/1)

      if Enum.empty?(items) do
        []
      else
        [
          "## ",
          type,
          "-Specific Configuration\n\n",
          "| Setting | Value |\n",
          "| --- | --- |\n",
          Enum.map(items, fn {label, value} ->
            ["| **", label, "** | ", value, " |\n"]
          end),
          "\n\n"
        ]
      end
    end

    @spec require_atomic_config(Actions.Update.t() | Actions.Destroy.t()) ::
            {String.t(), String.t()} | nil
    defp require_atomic_config(%{require_atomic?: true}), do: {"Require Atomic", "Yes"}
    defp require_atomic_config(_), do: nil

    @spec atomic_upgrade_config(Actions.Update.t() | Actions.Destroy.t()) ::
            {String.t(), String.t()} | nil
    defp atomic_upgrade_config(%{atomic_upgrade?: true}), do: {"Atomic Upgrade", "Yes"}
    defp atomic_upgrade_config(_), do: nil

    @spec atomic_upgrade_with_config(Actions.Update.t() | Actions.Destroy.t()) ::
            {String.t(), iodata()} | nil
    defp atomic_upgrade_with_config(%{atomic_upgrade_with: action}) when not is_nil(action) do
      {"Atomic Upgrade With", "`#{action}`"}
    end

    defp atomic_upgrade_with_config(_), do: nil

    @spec generic_specific_section(Actions.Action.t()) :: iodata()
    defp generic_specific_section(action) do
      items = [
        returns_config(action),
        allow_nil_config(action)
      ]

      items = Enum.reject(items, &is_nil/1)

      if Enum.empty?(items) do
        []
      else
        [
          "## Generic Action Configuration\n\n",
          "| Setting | Value |\n",
          "| --- | --- |\n",
          Enum.map(items, fn {label, value} ->
            ["| **", label, "** | ", value, " |\n"]
          end),
          "\n\n"
        ]
      end
    end

    @spec returns_config(Actions.Action.t()) :: {String.t(), iodata()} | nil
    defp returns_config(%{returns: type}) when not is_nil(type) do
      {"Returns", format_type_with_link(type)}
    end

    defp returns_config(_), do: nil

    @spec allow_nil_config(Actions.Action.t()) :: {String.t(), String.t()} | nil
    defp allow_nil_config(%{allow_nil?: allow_nil?}) when not is_nil(allow_nil?) do
      {"Allow Nil", format_boolean(allow_nil?)}
    end

    defp allow_nil_config(_), do: nil

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

    @spec format_atom_list([atom()]) :: iodata()
    defp format_atom_list(list) do
      list
      |> Enum.map(&["`", to_string(&1), "`"])
      |> Enum.intersperse(", ")
    end

    @spec format_module_list([module()]) :: iodata()
    defp format_module_list(list) do
      list
      |> Enum.map(&inspect/1)
      |> Enum.intersperse(", ")
    end

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
