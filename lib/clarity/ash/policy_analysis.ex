with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Ash.PolicyAnalysis do
    @moduledoc """
    Static analysis of Ash policies, shared by the security-lens content providers.

    Resolves whether a policy's condition governs a given action using only
    statically decidable condition checks (`Static`, `ActionType`, `Action`).
    Anything that can only be decided at runtime is reported as `:unknown`
    rather than guessed — over-claiming coverage is the fastest way for a
    security view to lose trust.
    """

    alias Ash.Resource.Actions

    @type coverage() :: :applies | :excluded | :unknown

    @doc """
    Whether `policy`'s condition governs `action`.

    Returns `:applies` or `:excluded` when the condition is statically
    decidable, and `:unknown` when it contains a runtime-only check.
    """
    @spec coverage(Ash.Policy.Policy.t(), Actions.action()) :: coverage()
    def coverage(policy, action) do
      policy.condition
      |> List.wrap()
      |> Enum.reduce(:applies, fn check, acc -> combine(acc, condition_decides(check, action)) end)
    end

    @spec combine(coverage(), coverage()) :: coverage()
    defp combine(:excluded, _), do: :excluded
    defp combine(_, :excluded), do: :excluded
    defp combine(:unknown, _), do: :unknown
    defp combine(_, :unknown), do: :unknown
    defp combine(:applies, :applies), do: :applies

    @spec condition_decides(term(), Actions.action()) :: coverage()
    defp condition_decides({Ash.Policy.Check.Static, opts}, _action) do
      if opts[:result], do: :applies, else: :excluded
    end

    defp condition_decides({Ash.Policy.Check.ActionType, opts}, action) do
      if action.type in List.wrap(opts[:type]), do: :applies, else: :excluded
    end

    defp condition_decides({Ash.Policy.Check.Action, opts}, action) do
      if action.name in List.wrap(opts[:action]), do: :applies, else: :excluded
    end

    defp condition_decides(_check, _action), do: :unknown
  end
end
