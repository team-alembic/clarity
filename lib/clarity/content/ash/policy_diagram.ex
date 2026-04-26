with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Content.Ash.PolicyDiagram do
    @moduledoc """
    D2 flowchart of an Ash resource's authorization policies.

    Each policy becomes a container with its condition (when applicable)
    and the ordered checks (`authorize_if`, `forbid_if`, etc.). Bypass
    policies are highlighted and short-circuit the evaluation flow:
    a passing bypass jumps straight to the `Allow` terminal node.

    Non-bypass policies all need to pass for the request to be allowed,
    so they're drawn as a vertical chain feeding into the same `Allow`
    terminal. Any forbid check or unmet bypass condition leads to
    `Forbid`. The result is a quick visual answer to "what gates this
    resource?".
    """

    @behaviour Clarity.Content

    alias Ash.Policy.Check
    alias Ash.Policy.Info, as: PolicyInfo
    alias Ash.Policy.Policy
    alias Ash.Resource.Info, as: ResourceInfo
    alias Clarity.Content.D2.Helpers
    alias Clarity.Vertex.Ash.Resource

    @impl Clarity.Content
    def name, do: "Policy Diagram"

    @impl Clarity.Content
    def description, do: "Visual flowchart of this resource's authorization policies"

    @impl Clarity.Content
    def sort_priority, do: -65

    @impl Clarity.Content
    def applies?(%Resource{resource: resource}, _lens) do
      Ash.Policy.Authorizer in ResourceInfo.authorizers(resource) and
        PolicyInfo.policies(resource) != []
    end

    def applies?(_vertex, _lens), do: false

    @impl Clarity.Content
    def render_static(%Resource{resource: resource}, _lens) do
      {:d2, fn _props -> to_d2(resource) end}
    end

    @spec to_d2(Ash.Resource.t()) :: iodata()
    defp to_d2(resource) do
      policies = PolicyInfo.policies(resource)
      indexed = Enum.with_index(policies)

      [
        "direction: down\n",
        terminal_nodes(),
        Enum.map(indexed, &policy_block/1),
        flow_edges(indexed)
      ]
    end

    @spec terminal_nodes() :: iodata()
    defp terminal_nodes do
      [
        ~s(request: "Request" { shape: oval; style: { fill: "#dbeafe" } }\n),
        ~s(allow: "Allow" { shape: oval; style: { fill: "#dcfce7"; stroke: "#15803d" } }\n),
        ~s(forbid: "Forbid" { shape: oval; style: { fill: "#fee2e2"; stroke: "#b91c1c" } }\n)
      ]
    end

    @spec policy_block({Policy.t(), non_neg_integer()}) :: iodata()
    defp policy_block({policy, idx}) do
      id = "policy_" <> Integer.to_string(idx)
      title = policy_title(policy, idx)

      [
        id,
        ": ",
        Helpers.quoted(title),
        " {\n",
        "  shape: package\n",
        if policy.bypass? do
          "  style: { fill: \"#fef3c7\"; stroke: \"#a16207\" }\n"
        else
          []
        end,
        condition_block(policy.condition),
        policy.policies
        |> Enum.with_index()
        |> Enum.map(fn {check, check_idx} -> check_node(id, check, check_idx) end),
        "}\n"
      ]
    end

    @spec policy_title(Policy.t(), non_neg_integer()) :: String.t()
    defp policy_title(%{description: desc}, _idx) when is_binary(desc), do: desc

    defp policy_title(%{bypass?: true}, idx), do: "Bypass " <> Integer.to_string(idx + 1)

    defp policy_title(_policy, idx), do: "Policy " <> Integer.to_string(idx + 1)

    @spec condition_block(term()) :: iodata()
    defp condition_block(empty) when empty in [nil, []], do: []

    defp condition_block(conditions) do
      label = "When: " <> describe_conditions(List.wrap(conditions))

      [
        "  condition: ",
        Helpers.quoted(label),
        " { shape: diamond }\n"
      ]
    end

    @spec check_node(String.t(), Check.t(), non_neg_integer()) :: iodata()
    defp check_node(_policy_id, check, idx) do
      label =
        IO.iodata_to_binary([
          Atom.to_string(check.type),
          ": ",
          describe_check(check)
        ])

      shape =
        case check.type do
          :authorize_if -> "rectangle"
          :forbid_if -> "rectangle"
          _ -> "rectangle"
        end

      colour =
        case check.type do
          :authorize_if -> "  style.fill: \"#dcfce7\"\n"
          :forbid_if -> "  style.fill: \"#fee2e2\"\n"
          :authorize_unless -> "  style.fill: \"#dcfce7\"\n"
          :forbid_unless -> "  style.fill: \"#fee2e2\"\n"
        end

      [
        "  check_",
        Integer.to_string(idx),
        ": ",
        Helpers.quoted(label),
        " {\n",
        "    shape: ",
        shape,
        "\n",
        "  ",
        colour,
        "  }\n",
        "  ",
        if(idx == 0, do: ["condition -> check_0\n"], else: [])
      ]
    end

    @spec flow_edges([{Policy.t(), non_neg_integer()}]) :: iodata()
    defp flow_edges(indexed) do
      first_id = first_policy_id(indexed)

      entry_edge =
        case first_id do
          nil -> []
          id -> ["request -> ", id, "\n"]
        end

      bypass_to_allow =
        Enum.flat_map(indexed, fn {policy, idx} ->
          if policy.bypass? do
            [["policy_", Integer.to_string(idx), " -> allow: \"if pass\"\n"]]
          else
            []
          end
        end)

      sequential_chain =
        indexed
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [{_p1, i1}, {_p2, i2}] ->
          [
            "policy_",
            Integer.to_string(i1),
            " -> policy_",
            Integer.to_string(i2),
            "\n"
          ]
        end)

      last_to_allow =
        case List.last(indexed) do
          {_, last_idx} ->
            ["policy_", Integer.to_string(last_idx), " -> allow\n"]

          nil ->
            []
        end

      forbid_edges =
        Enum.map(indexed, fn {_policy, idx} ->
          ["policy_", Integer.to_string(idx), " -> forbid: \"if fail\"\n"]
        end)

      [entry_edge, bypass_to_allow, sequential_chain, last_to_allow, forbid_edges]
    end

    @spec first_policy_id([{Policy.t(), non_neg_integer()}]) :: String.t() | nil
    defp first_policy_id([{_policy, idx} | _]), do: "policy_" <> Integer.to_string(idx)
    defp first_policy_id([]), do: nil

    @spec describe_conditions([term()]) :: String.t()
    defp describe_conditions(conditions) do
      Enum.map_join(conditions, " and ", &describe_check/1)
    end

    @spec describe_check(term()) :: String.t()
    defp describe_check(%{check_module: module, check_opts: opts}) do
      try_describe(module, opts)
    end

    defp describe_check({module, opts}) when is_atom(module) and is_list(opts) do
      try_describe(module, opts)
    end

    defp describe_check(check), do: inspect(check)

    @spec try_describe(module(), keyword()) :: String.t()
    defp try_describe(module, opts) do
      module
      |> Check.describe(opts)
      |> to_string()
      |> String.replace(~r/\s+/, " ")
      |> String.trim()
      |> truncate(80)
    rescue
      _ -> inspect(module)
    end

    @spec truncate(String.t(), pos_integer()) :: String.t()
    defp truncate(string, max) do
      if byte_size(string) > max do
        binary_part(string, 0, max - 1) <> "…"
      else
        string
      end
    end
  end
end
