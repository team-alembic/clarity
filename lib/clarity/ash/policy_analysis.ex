with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Ash.PolicyAnalysis do
    @moduledoc """
    Static analysis of Ash policies, shared by the security-lens content providers.

    Two analyses are offered:

    * `coverage/2` resolves whether a policy's condition governs an action using
      only statically decidable condition checks (`Static`, `ActionType`,
      `Action`); anything runtime-only is `:unknown`, never guessed.

    * `action_verdict/3` asks Ash's own SAT solver whether a given actor can
      reach an action; `actor_profiles/1` resolves the set of actors to test.

    ## Actor profiles

    Configure explicitly with a `label => spec` map. A spec is an Ash resource
    module (→ empty struct, so attributes take their declared defaults), a plain
    struct module (→ empty struct), a non-struct module (→ used as-is), an actor
    struct/map (→ used as-is), or `nil` for an anonymous actor:

        config :clarity, :security_actors, %{
          "User" => MyApp.Accounts.User,
          "System" => MyApp.SystemActor
        }

    Unconfigured, profiles are detected from the AshAuthentication installer
    conventions:

    * `"Anonymous"` → `nil`
    * `"User"` → `<App>.Accounts.User`, when it is an Ash resource
    * `"API key"` → the same user struct tagged `__metadata__.using_api_key?`,
      when `<App>.Accounts.ApiKey` is also present (the api-key actor in
      AshAuthentication is the user, flagged via metadata)
    """

    alias Ash.Policy.Authorizer
    alias Ash.Policy.Checker
    alias Ash.Resource.Actions
    alias Ash.Resource.Info

    @authorizer Authorizer

    @type coverage() :: :applies | :excluded | :unknown
    @type verdict() :: :unrestricted | :always | :conditional | :never
    @type actor() :: struct() | map() | module() | nil

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
    The set of labelled actors to test for reachability.

    See the module docs for configuration and the conventional defaults.
    """
    @spec actor_profiles(Ash.Resource.t()) :: [{String.t(), actor()}]
    def actor_profiles(resource) do
      case Application.get_env(:clarity, :security_actors) do
        nil ->
          default_profiles(resource)

        actors when is_map(actors) ->
          actors
          |> Enum.map(fn {label, spec} -> {label, build_actor(spec)} end)
          |> Enum.sort_by(&elem(&1, 0))
      end
    end

    @doc """
    Whether `actor` can reach `action`, via Ash's SAT solver.

    Returns `:unrestricted` when the resource has no policy authorizer,
    `:always` when authorisation is a tautology (open to any actor),
    `:never` when no scenario authorises `actor`, and `:conditional` when it
    depends on runtime checks (e.g. row filters).
    """
    @spec action_verdict(Ash.Resource.t(), Actions.action(), actor()) :: verdict()
    def action_verdict(resource, action, actor) do
      if @authorizer in Info.authorizers(resource) do
        solve(resource, action, actor)
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

    @spec solve(Ash.Resource.t(), Actions.action(), actor()) :: verdict()
    defp solve(resource, action, actor) do
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

    @spec default_profiles(Ash.Resource.t()) :: [{String.t(), struct() | nil}]
    defp default_profiles(resource) do
      case conventional_resource(resource, "User") do
        nil ->
          [{"Anonymous", nil}]

        user ->
          base = [{"Anonymous", nil}, {"User", struct(user)}]

          if conventional_resource(resource, "ApiKey") do
            base ++ [{"API key", struct(user, __metadata__: %{using_api_key?: true})}]
          else
            base
          end
      end
    end

    @spec conventional_resource(Ash.Resource.t(), String.t()) :: module() | nil
    defp conventional_resource(resource, name) do
      candidate = Module.concat([resource |> Module.split() |> hd(), "Accounts", name])
      if ash_resource?(candidate), do: candidate
    end

    @spec build_actor(actor()) :: actor()
    defp build_actor(nil), do: nil
    defp build_actor(actor) when is_map(actor), do: actor

    defp build_actor(module) when is_atom(module) do
      cond do
        not Code.ensure_loaded?(module) -> module
        ash_resource?(module) -> struct(module)
        function_exported?(module, :__struct__, 0) -> struct(module)
        true -> module
      end
    end

    @spec ash_resource?(term()) :: boolean()
    defp ash_resource?(module),
      do: is_atom(module) and Code.ensure_loaded?(module) and Info.resource?(module)

    @spec subject(Ash.Resource.t(), Actions.action(), actor()) ::
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
