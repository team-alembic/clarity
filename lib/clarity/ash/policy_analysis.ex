with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Ash.PolicyAnalysis do
    @moduledoc """
    Static analysis of Ash policies, shared by the security-lens content providers.

    Two analyses are offered:

    * `coverage/2` resolves whether a policy's condition governs an action using
      only statically decidable condition checks (`Static`, `ActionType`,
      `Action`); anything runtime-only is `:unknown`, never guessed.

    * `action_verdict/2` asks Ash's own SAT solver whether an action is
      reachable, treating actor-dependent checks as free variables. The verdict
      is computed for a *representative actor with no privileged attributes*, so
      it answers "can an ordinary actor reach this action?" — admin/bypass paths
      are reported separately.

    ## Representative actor

    The actor used for `action_verdict/2` is, in order of preference:

    1. `config :clarity, :security_actor, ...` — a resource module (instantiated
       as an empty struct) or an actor struct/map.
    2. The AshAuthentication installer convention `<App>.Accounts.User`, if that
       module exists and is an Ash resource — instantiated as an empty struct so
       its attributes take their declared defaults (an unprivileged user).
    3. A bare `%{id: _}` map.
    """

    alias Ash.Policy.Authorizer
    alias Ash.Policy.Checker
    alias Ash.Resource.Actions
    alias Ash.Resource.Info

    @authorizer Authorizer

    @type coverage() :: :applies | :excluded | :unknown
    @type verdict() :: :unrestricted | :always | :conditional | :never

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

    @doc """
    Whether an ordinary actor can reach `action`, via Ash's SAT solver.

    Returns `:unrestricted` when the resource has no policy authorizer,
    `:always` when authorisation is a tautology (open to any actor),
    `:never` when no scenario authorises a representative non-privileged actor,
    and `:conditional` when it depends on runtime checks (e.g. row filters).
    """
    @spec action_verdict(Ash.Resource.t(), Actions.action()) :: verdict()
    def action_verdict(resource, action) do
      if @authorizer in Info.authorizers(resource) do
        solve(resource, action)
      else
        :unrestricted
      end
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

    @fallback_actor %{id: "00000000-0000-0000-0000-000000000000"}

    @spec solve(Ash.Resource.t(), Actions.action()) :: verdict()
    defp solve(resource, action) do
      actor = representative_actor(resource)
      subject = subject(resource, action, actor)

      authorizer =
        Checker.strict_check_all_facts(%Authorizer{
          resource: resource,
          action: action,
          policies: Ash.Policy.Info.policies(resource),
          actor: actor,
          query: if(action.type == :read, do: subject),
          changeset: if(action.type in [:create, :update, :destroy], do: subject),
          subject: subject,
          domain: Info.domain(resource),
          facts: %{true => true, false => false},
          context: %{}
        })

      case Checker.strict_check_scenarios(authorizer) do
        {:ok, true, _authorizer} -> :always
        {:ok, scenarios, _authorizer} when is_list(scenarios) -> :conditional
        _otherwise -> :never
      end
    end

    @spec representative_actor(Ash.Resource.t()) :: struct() | map()
    defp representative_actor(resource) do
      configured_actor() || conventional_actor(resource)
    end

    @spec configured_actor() :: struct() | map() | nil
    defp configured_actor do
      case Application.get_env(:clarity, :security_actor) do
        nil -> nil
        module when is_atom(module) -> if ash_resource?(module), do: struct(module)
        actor when is_map(actor) -> actor
        _other -> nil
      end
    end

    @spec conventional_actor(Ash.Resource.t()) :: struct() | map()
    defp conventional_actor(resource) do
      candidate = Module.concat([resource |> Module.split() |> hd(), "Accounts", "User"])
      if ash_resource?(candidate), do: struct(candidate), else: @fallback_actor
    end

    @spec ash_resource?(module()) :: boolean()
    defp ash_resource?(module), do: Code.ensure_loaded?(module) and Info.resource?(module)

    @spec subject(Ash.Resource.t(), Actions.action(), struct() | map()) ::
            Ash.Query.t() | Ash.Changeset.t()
    defp subject(resource, %{type: :read} = action, actor),
      do: Ash.Query.for_read(resource, action.name, %{}, actor: actor, authorize?: false)

    defp subject(resource, %{type: :create} = action, actor),
      do: Ash.Changeset.for_create(resource, action.name, %{}, actor: actor, authorize?: false)

    defp subject(resource, %{type: :update} = action, actor),
      do:
        Ash.Changeset.for_update(struct(resource), action.name, %{},
          actor: actor,
          authorize?: false
        )

    defp subject(resource, %{type: :destroy} = action, actor),
      do:
        Ash.Changeset.for_destroy(struct(resource), action.name, %{},
          actor: actor,
          authorize?: false
        )
  end
end
