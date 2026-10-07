with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Vertex.Ash.Policy do
    @moduledoc """
    Vertex implementation for Ash resource policies.

    Represents a policy definition in an Ash resource that controls authorization.
    """
    alias Ash.Policy.Check
    alias Ash.Policy.Policy
    alias Clarity.SourceLocation
    alias Clarity.Vertex.HintProvider

    @type t() :: %__MODULE__{
            policy: Policy.t(),
            resource: Ash.Resource.t()
          }
    @enforce_keys [:policy, :resource]
    defstruct [:policy, :resource]

    @doc """
    A one-line label for `policy`: what it covers, then what it requires.

    Reads `"read actions: authorize if id == actor.id"` or, for a bypass,
    `"bypass: actor.admin == true"`. Checks that always authorize are left out,
    and further checks are counted (`"(+2)"`). A policy's own description, when
    it has one, is used as is.
    """
    @spec label(Policy.t()) :: String.t()
    def label(policy) do
      if described?(policy), do: policy.description, else: summarise(policy)
    end

    @spec summarise(Policy.t()) :: String.t()
    defp summarise(policy) do
      {scopes, others} =
        policy.condition |> List.wrap() |> Enum.reject(&always?/1) |> Enum.split_with(&scope?/1)

      checks = Enum.reject(policy.policies, &always_authorizes?/1)
      {whens, rule} = rule(policy.bypass?, others, checks)
      bypass = if policy.bypass?, do: ["bypass"], else: []

      head =
        case bypass ++ Enum.map(scopes, &describe_scope/1) ++ whens do
          [] -> "all actions"
          parts -> Enum.join(parts, " ")
        end

      head <> ": " <> rule
    end

    @doc """
    Describes a policy condition in Ash's own words, e.g. `"action.type == :read"`.
    """
    @spec describe_condition(Check.ref()) :: String.t()
    def describe_condition({module, opts}), do: tidy(module.describe(opts))
    def describe_condition(other), do: inspect(other)

    @doc """
    Describes a policy check, e.g. `"authorize if actor.admin == true"`.
    """
    @spec describe_check(Check.t()) :: String.t()
    def describe_check(%{type: type, check_module: module, check_opts: opts}),
      do: "#{type |> Atom.to_string() |> String.replace("_", " ")} #{tidy(module.describe(opts))}"

    @spec described?(Policy.t()) :: boolean()
    defp described?(%{description: description}),
      do: is_binary(description) and String.trim(description) != ""

    # A bypass whose checks always authorize is granted by its condition.
    @spec rule(boolean() | nil, [Check.ref()], [Check.t()]) :: {[String.t()], String.t()}
    defp rule(true, [_ | _] = others, []),
      do: {[], Enum.map_join(others, " and ", &describe_condition/1)}

    defp rule(bypass?, others, checks) do
      whens = Enum.map(others, &("when " <> describe_condition(&1)))
      describe = if bypass?, do: &describe_bypass_check/1, else: &describe_check/1

      rule =
        case checks do
          [] -> "always authorize"
          [check] -> describe.(check)
          [check | rest] -> "#{describe.(check)} (+#{length(rest)})"
        end

      {whens, rule}
    end

    # Authorizing is what a bypass does, so "authorize if" goes without saying.
    @spec describe_bypass_check(Check.t()) :: String.t()
    defp describe_bypass_check(%{type: :authorize_if, check_module: module, check_opts: opts}),
      do: tidy(module.describe(opts))

    defp describe_bypass_check(check), do: describe_check(check)

    @spec scope?(Check.ref()) :: boolean()
    defp scope?({module, _opts}), do: module in [Check.ActionType, Check.Action]
    defp scope?(_other), do: false

    @spec describe_scope(Check.ref()) :: String.t()
    defp describe_scope({Check.ActionType, opts}), do: actions(opts[:type], "actions")
    defp describe_scope({Check.Action, opts}), do: actions(opts[:action], "action")

    @spec actions(atom() | [atom()], String.t()) :: String.t()
    defp actions(names, noun) do
      names = List.wrap(names)
      noun = if length(names) > 1, do: String.trim_trailing(noun, "s") <> "s", else: noun
      Enum.join(names, ", ") <> " " <> noun
    end

    @spec always?(Check.ref()) :: boolean()
    defp always?({Check.Static, opts}), do: opts[:result] == true
    defp always?(_other), do: false

    @spec always_authorizes?(Check.t()) :: boolean()
    defp always_authorizes?(%{type: :authorize_if, check_module: Check.Static, check_opts: opts}),
      do: opts[:result] == true

    defp always_authorizes?(_check), do: false

    # Ash describes actor and argument references as `{:_actor, :id}`.
    @spec tidy(String.t()) :: String.t()
    defp tidy(description),
      do: Regex.replace(~r/\{:_(actor|arg), :(\w+[?!]?)\}/, description, "\\1.\\2")

    defimpl Clarity.Vertex do
      alias Clarity.Vertex.Util

      @impl Clarity.Vertex
      def id(%@for{policy: policy, resource: resource}) do
        Util.id(@for, [resource, policy])
      end

      @impl Clarity.Vertex
      def type_label(%@for{policy: %{bypass?: true}}), do: "Bypass Policy"
      def type_label(_vertex), do: "Policy"

      @impl Clarity.Vertex
      def name(%@for{policy: policy}), do: @for.label(policy)
    end

    defimpl Clarity.Vertex.GraphGroupProvider do
      @impl Clarity.Vertex.GraphGroupProvider
      def graph_group(%@for{resource: resource}), do: [inspect(resource), "Policies"]
    end

    defimpl Clarity.Vertex.GraphShapeProvider do
      @impl Clarity.Vertex.GraphShapeProvider
      def shape(_vertex), do: "house"
    end

    defimpl Clarity.Vertex.SourceLocationProvider do
      @impl Clarity.Vertex.SourceLocationProvider
      def source_location(%{policy: policy, resource: resource}) do
        SourceLocation.from_spark_entity(resource, policy)
      end
    end

    defimpl Clarity.Vertex.TooltipProvider do
      @impl Clarity.Vertex.TooltipProvider
      def tooltip(%@for{policy: policy, resource: resource}) do
        [
          "**Policy** on Resource: `",
          inspect(resource),
          "`\n\n",
          if policy.description do
            [policy.description, "\n\n"]
          else
            []
          end,
          "**Type:** ",
          if(policy.bypass?, do: "Bypass", else: "Regular"),
          "\n\n",
          if policy.access_type do
            ["**Access Type:** ", inspect(policy.access_type), "\n\n"]
          else
            []
          end,
          "**Condition:** ",
          format_condition(policy.condition),
          "\n\n",
          case policy.policies do
            [] ->
              []

            checks ->
              [
                "## Checks\n",
                Enum.map(checks, fn check ->
                  [
                    "- **",
                    format_check_type(check.type),
                    "**: `",
                    format_check_module(check.check_module),
                    "`\n"
                  ]
                end)
              ]
          end
        ]
      end

      @spec format_condition(list() | term()) :: String.t()
      defp format_condition(condition) when is_list(condition) do
        Enum.map_join(condition, ", ", fn
          {module, opts} -> "`#{format_check_module(module)}(#{format_opts(opts)})`"
          other -> "`#{inspect(other)}`"
        end)
      end

      defp format_condition(condition), do: "`#{inspect(condition)}`"

      @spec format_check_type(atom()) :: String.t()
      defp format_check_type(:authorize_if), do: "Authorize If"
      defp format_check_type(:forbid_if), do: "Forbid If"
      defp format_check_type(:forbid_unless), do: "Forbid Unless"
      defp format_check_type(:authorize_unless), do: "Authorize Unless"
      defp format_check_type(other), do: inspect(other)

      @spec format_check_module(module()) :: String.t()
      defp format_check_module(module) do
        module |> Module.split() |> List.last()
      end

      @spec format_opts(list() | term()) :: String.t()
      defp format_opts(opts) when is_list(opts) and opts != [] do
        Enum.map_join(opts, ", ", fn {k, v} -> "#{k}: #{inspect(v)}" end)
      end

      defp format_opts(_), do: ""
    end

    defimpl Clarity.Vertex.HintProvider do
      @impl HintProvider
      def icon(_vertex), do: :policy

      @impl HintProvider
      def badges(_vertex), do: []

      @impl HintProvider
      def facts(%@for{policy: policy, resource: resource}) do
        [
          {"Resource", inspect(resource)},
          {"Condition",
           policy.condition |> List.wrap() |> Enum.map_join(", ", &@for.describe_condition/1)}
          | case policy.policies do
              [] -> []
              checks -> [{"Checks", Enum.map(checks, &@for.describe_check/1)}]
            end
        ]
      end
    end
  end
end
