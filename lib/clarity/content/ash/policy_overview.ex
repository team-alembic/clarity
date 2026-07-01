with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Content.Ash.PolicyOverview do
    @moduledoc """
    Content provider for Ash Policy overview.

    Displays comprehensive information about an Ash policy including its type,
    conditions, and checks.
    """

    @behaviour Clarity.Content

    alias Ash.Policy.Check
    alias Ash.Resource.Info
    alias Clarity.Ash.PolicyAnalysis
    alias Clarity.Perspective.Lens
    alias Clarity.Vertex.Ash.Policy
    alias Clarity.Vertex.Ash.Resource
    alias Clarity.Vertex.Util

    @impl Clarity.Content
    def name, do: "Policy Overview"

    @impl Clarity.Content
    def description, do: "Overview of this Ash policy"

    @impl Clarity.Content
    def sort_priority, do: -100

    @impl Clarity.Content
    def applies?(%Policy{}, _lens), do: true
    def applies?(_vertex, _lens), do: false

    @impl Clarity.Content
    def render_static(%Policy{policy: policy, resource: resource}, %Lens{id: "security"}) do
      {:markdown, fn _props -> security_markdown(policy, resource) end}
    end

    def render_static(%Policy{policy: policy, resource: resource}, _lens) do
      {:markdown, fn _props -> generate_markdown(policy, resource) end}
    end

    @spec generate_markdown(Ash.Policy.Policy.t(), Ash.Resource.t()) :: iodata()
    defp generate_markdown(policy, resource) do
      [
        policy_header(policy),
        policy_info_section(policy, resource),
        condition_section(policy),
        checks_section(policy),
        evaluation_note()
      ]
    end

    @spec security_markdown(Ash.Policy.Policy.t(), Ash.Resource.t()) :: iodata()
    defp security_markdown(policy, resource) do
      [
        policy_header(policy),
        policy_info_section(policy, resource),
        condition_section(policy),
        checks_section(policy),
        governed_actions_section(policy, resource),
        effectively_open_note(policy)
      ]
    end

    @spec governed_actions_section(Ash.Policy.Policy.t(), Ash.Resource.t()) :: iodata()
    defp governed_actions_section(policy, resource) do
      coverage = Enum.map(Info.actions(resource), &{&1, PolicyAnalysis.coverage(policy, &1)})
      governed = for {action, :applies} <- coverage, do: action
      unknown = for {action, :unknown} <- coverage, do: action

      [
        "## Governed Actions\n\n",
        "Actions this policy controls, resolved from its condition:\n\n",
        case governed do
          [] ->
            "_No actions are statically matched by this policy's condition._\n\n"

          _ ->
            [
              "| Action | Type |\n| --- | --- |\n",
              Enum.map(governed, &action_row(&1, resource)),
              "\n"
            ]
        end,
        case unknown do
          [] ->
            []

          _ ->
            [
              "> Some actions depend on runtime checks and could not be resolved ",
              "statically: ",
              Enum.map_join(unknown, ", ", &("`" <> Atom.to_string(&1.name) <> "`")),
              ".\n\n"
            ]
        end
      ]
    end

    @spec action_row(Ash.Resource.Actions.action(), Ash.Resource.t()) :: iodata()
    defp action_row(action, resource) do
      [
        "| [",
        Atom.to_string(action.name),
        "](vertex://",
        Util.id(Clarity.Vertex.Ash.Action, [resource, action.name]),
        ") | `",
        Atom.to_string(action.type),
        "` |\n"
      ]
    end

    @spec effectively_open_note(Ash.Policy.Policy.t()) :: iodata()
    defp effectively_open_note(policy) do
      if authorizes_anyone?(policy) do
        "> ⚠ This policy authorises **any actor** when reached (`authorize_if always()`).\n\n"
      else
        []
      end
    end

    @spec authorizes_anyone?(Ash.Policy.Policy.t()) :: boolean()
    defp authorizes_anyone?(policy) do
      Enum.any?(policy.policies, fn check ->
        check.type == :authorize_if and check.check_module == Ash.Policy.Check.Static and
          check.check_opts[:result] == true
      end)
    end

    @spec policy_header(Ash.Policy.Policy.t()) :: iodata()
    defp policy_header(policy) do
      policy_type = if policy.bypass?, do: "Bypass Policy", else: "Standard Policy"

      [
        "# ",
        policy_type,
        "\n\n"
      ]
    end

    @spec policy_info_section(Ash.Policy.Policy.t(), Ash.Resource.t()) :: iodata()
    defp policy_info_section(policy, resource) do
      [
        "## Policy Information\n\n",
        "| Property | Value |\n",
        "| --- | --- |\n",
        "| **Type** | ",
        if(policy.bypass?, do: "Bypass", else: "Standard"),
        " |\n",
        "| **Resource** | [",
        inspect(resource),
        "](vertex://",
        Util.id(Resource, [resource]),
        ") |\n",
        case policy.description do
          nil -> []
          "" -> []
          description -> ["| **Description** | ", clean_description(description), " |\n"]
        end,
        case Map.get(policy, :access_type) do
          nil -> []
          access_type -> ["| **Access Type** | `", to_string(access_type), "` |\n"]
        end,
        "\n\n",
        if policy.bypass? do
          [
            "> **Note:** This is a bypass policy. When its checks pass, ",
            "other policies are skipped for this request.\n\n"
          ]
        else
          []
        end
      ]
    end

    @spec condition_section(Ash.Policy.Policy.t()) :: iodata()
    defp condition_section(policy) do
      condition = Map.get(policy, :condition, [])

      if is_nil(condition) or condition == [] do
        []
      else
        [
          "## Conditions\n\n",
          "This policy applies when:\n\n",
          format_condition(condition),
          "\n\n"
        ]
      end
    end

    @spec format_condition([Check.ref()]) :: iodata()
    defp format_condition(condition) when is_list(condition) do
      Enum.map_intersperse(condition, "\n", &format_condition_item/1)
    end

    defp format_condition(condition) do
      ["```elixir\n", inspect(condition, pretty: true), "\n```"]
    end

    @spec format_condition_item(Check.ref()) :: iodata()
    defp format_condition_item({module, opts}) when is_atom(module) do
      if Enum.empty?(opts) do
        ["- `", inspect(module), "`"]
      else
        ["- `", inspect(module), "` with options: `", inspect(opts), "`"]
      end
    end

    defp format_condition_item(item) do
      ["- `", inspect(item), "`"]
    end

    @spec checks_section(Ash.Policy.Policy.t()) :: iodata()
    defp checks_section(policy) do
      checks = Map.get(policy, :policies, [])

      if Enum.empty?(checks) do
        []
      else
        [
          "## Checks\n\n",
          "| Type | Check | Description |\n",
          "| --- | --- | --- |\n",
          Enum.map_intersperse(checks, "", &check_row/1),
          "\n\n"
        ]
      end
    end

    @spec check_row(Check.t()) :: iodata()
    defp check_row(check) do
      {check_type, check_module, check_description} = extract_check_info(check)

      [
        "| `",
        to_string(check_type),
        "` | `",
        inspect(check_module),
        "` | ",
        check_description,
        " |\n"
      ]
    end

    @spec extract_check_info(Check.t() | Check.ref()) ::
            {atom(), module() | String.t(), String.t()}
    defp extract_check_info(%{type: type, check_module: module} = check) do
      description = format_check_description(check)
      {type, module, description}
    end

    defp extract_check_info(%{check: {module, opts}} = check) do
      type = Map.get(check, :type, :authorize_if)
      description = format_check_opts(opts)
      {type, module, description}
    end

    defp extract_check_info(%{check: module} = check) when is_atom(module) do
      type = Map.get(check, :type, :authorize_if)
      {type, module, ""}
    end

    defp extract_check_info(check) when is_tuple(check) do
      case check do
        {module, opts} when is_atom(module) ->
          {:authorize_if, module, format_check_opts(opts)}

        _ ->
          {:authorize_if, inspect(check), ""}
      end
    end

    defp extract_check_info(check) do
      {:authorize_if, inspect(check), ""}
    end

    @spec format_check_description(map()) :: String.t()
    defp format_check_description(check) do
      opts = Map.get(check, :opts, [])
      description = Map.get(check, :description)

      cond do
        not is_nil(description) and description != "" -> description
        not Enum.empty?(opts) -> format_check_opts(opts)
        true -> ""
      end
    end

    @spec format_check_opts(Keyword.t()) :: String.t()
    defp format_check_opts([]), do: ""

    defp format_check_opts(opts) when is_list(opts) do
      Enum.map_join(opts, ", ", fn {k, v} -> "#{k}: `#{inspect(v)}`" end)
    end

    @spec evaluation_note() :: iodata()
    defp evaluation_note do
      [
        "## Policy Evaluation\n\n",
        "Checks are evaluated from top to bottom. The **first check that produces a decision** ",
        "determines the policy result. If all checks pass without making a decision, ",
        "the default behavior depends on whether this is a bypass policy or a standard policy.\n\n",
        "- `authorize_if`: Authorizes the request if the check passes\n",
        "- `forbid_if`: Forbids the request if the check passes\n",
        "- `forbid_unless`: Forbids the request if the check fails\n",
        "- `authorize_unless`: Authorizes the request if the check fails\n\n"
      ]
    end

    @spec clean_description(String.t()) :: String.t()
    defp clean_description(description) when is_binary(description) do
      description
      |> String.trim()
      |> String.replace("\n", " ")
      |> String.replace(~r/\s+/, " ")
    end
  end
end
