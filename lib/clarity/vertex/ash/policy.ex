with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Vertex.Ash.Policy do
    @moduledoc """
    Vertex implementation for Ash resource policies.

    Represents a policy definition in an Ash resource that controls authorization.
    """
    alias Clarity.SourceLocation

    @type t() :: %__MODULE__{
            policy: Ash.Policy.Policy.t(),
            resource: Ash.Resource.t()
          }
    @enforce_keys [:policy, :resource]
    defstruct [:policy, :resource]

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
      def name(%@for{policy: policy}) do
        cond do
          policy.description && String.trim(policy.description) != "" ->
            policy.description

          policy.bypass? ->
            "Bypass: #{format_condition(policy.condition)}"

          true ->
            format_condition(policy.condition)
        end
      end

      @spec format_condition(list() | term()) :: String.t()
      defp format_condition(condition) when is_list(condition) do
        Enum.map_join(condition, ", ", fn
          {module, _opts} -> module |> Module.split() |> List.last()
          other -> inspect(other)
        end)
      end

      defp format_condition(condition), do: inspect(condition)
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
  end
end
