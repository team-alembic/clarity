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

    require Logger

    @authorizer Authorizer

    @type coverage() :: :applies | :excluded | :unknown
    @type verdict() :: :unrestricted | :always | :conditional | :never | :unknown
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
    depends on runtime checks (e.g. row filters). Returns `:unknown` when a
    policy check raises.

    The checks see an empty query, changeset or input, with the action, domain
    and actor set, and with the static defaults of the action's arguments and
    attributes. The action's own preparations, changes and validations do not
    run, and neither do function defaults.
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

      authorizer = %Authorizer{
        resource: resource,
        action: action,
        policies: Ash.Policy.Info.policies(resource),
        actor: actor,
        query: if(action.type == :read, do: subject),
        changeset: if(action.type in [:create, :update, :destroy], do: subject),
        action_input: if(action.type == :action, do: subject),
        subject: subject,
        domain: Info.domain(resource),
        facts: %{true => true, false => false},
        # Ash's authorizer type allows no nil here, and the solver does not read them.
        scenarios: [],
        real_scenarios: [],
        check_scenarios: [],
        context: %{}
      }

      authorizer |> Checker.strict_check_scenarios() |> scenarios_verdict()
    rescue
      exception ->
        log_raising_check(resource, action, exception, __STACKTRACE__)
        :unknown
    end

    @spec log_raising_check(
            Ash.Resource.t(),
            Actions.action(),
            Exception.t(),
            Exception.stacktrace()
          ) ::
            :ok
    defp log_raising_check(resource, action, exception, stacktrace) do
      Logger.debug(fn ->
        "Policy check #{inspect(raising_module(exception, stacktrace))} raised " <>
          "for #{inspect(resource)} action #{inspect(action.name)}"
      end)
    end

    @spec raising_module(Exception.t(), Exception.stacktrace()) :: module() | nil
    defp raising_module(%FunctionClauseError{module: module}, _stacktrace) when is_atom(module),
      do: module

    defp raising_module(_exception, [{module, _function, _arity, _location} | _]), do: module
    defp raising_module(_exception, _stacktrace), do: nil

    # `strict_check_scenarios/1` has no spec, so dialyzer infers its boolean
    # result as only ever `false` and rejects the `{:ok, true, _}` clause as an
    # impossible pattern. A tautology does return `{:ok, true, _}` at runtime
    # (verified), so the clause is real — silence the spurious warning.
    @type scenario_result() :: {:ok, boolean() | [map()], term()} | {:error, term(), term()}

    @dialyzer {:nowarn_function, scenarios_verdict: 1}
    @spec scenarios_verdict(scenario_result()) :: verdict()
    defp scenarios_verdict({:ok, scenarios, _authorizer}) when is_list(scenarios),
      do: :conditional

    defp scenarios_verdict({:ok, true, _authorizer}), do: :always
    defp scenarios_verdict({:ok, false, _authorizer}), do: :never
    defp scenarios_verdict({:error, _authorizer, _reason}), do: :never

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
      candidate = Module.safe_concat([resource |> Module.split() |> hd(), "Accounts", name])
      if ash_resource?(candidate), do: candidate
    rescue
      ArgumentError -> nil
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

    @spec ash_resource?(module()) :: boolean()
    defp ash_resource?(module), do: Code.ensure_loaded?(module) and Info.resource?(module)

    # Not `for_read/4` and its kin: they run the action's preparations, changes
    # and validations, which is host code. Static defaults are set as they do.
    @spec subject(Ash.Resource.t(), Actions.action(), actor()) ::
            Ash.Query.t() | Ash.Changeset.t() | Ash.ActionInput.t()
    defp subject(resource, action, actor) do
      resource
      |> blank_subject(action)
      |> then(&%{&1 | action: action, domain: Info.domain(resource)})
      |> set_argument_defaults(action)
      |> set_attribute_defaults(resource, action)
      |> Ash.Subject.set_context(%{private: %{actor: actor}})
    end

    @spec set_argument_defaults(
            Ash.Query.t() | Ash.Changeset.t() | Ash.ActionInput.t(),
            Actions.action()
          ) :: Ash.Query.t() | Ash.Changeset.t() | Ash.ActionInput.t()
    defp set_argument_defaults(subject, action) do
      action.arguments
      |> Enum.filter(&static_default?(&1.default))
      |> Enum.reduce(subject, fn argument, subject ->
        case Ash.Subject.fetch_argument(subject, argument.name) do
          {:ok, _value} -> subject
          :error -> Ash.Subject.set_argument(subject, argument.name, argument.default)
        end
      end)
    end

    @spec set_attribute_defaults(
            Ash.Query.t() | Ash.Changeset.t() | Ash.ActionInput.t(),
            Ash.Resource.t(),
            Actions.action()
          ) :: Ash.Query.t() | Ash.Changeset.t() | Ash.ActionInput.t()
    defp set_attribute_defaults(%Ash.Changeset{} = changeset, resource, %{type: type})
         when type in [:create, :update] do
      resource
      |> Info.static_default_attributes(type)
      |> Enum.reduce(changeset, fn attribute, changeset ->
        if Ash.Changeset.changing_attribute?(changeset, attribute.name) do
          changeset
        else
          Ash.Changeset.force_change_attribute(
            changeset,
            attribute.name,
            attribute_default(attribute, type)
          )
        end
      end)
    end

    defp set_attribute_defaults(subject, _resource, _action), do: subject

    @spec attribute_default(Ash.Resource.Attribute.t(), :create | :update) :: term()
    defp attribute_default(attribute, :create), do: attribute.default
    defp attribute_default(attribute, :update), do: attribute.update_default

    # Functions and `{module, function, args}` defaults are host code.
    @spec static_default?(term()) :: boolean()
    defp static_default?(nil), do: false
    defp static_default?(default) when is_function(default), do: false
    defp static_default?({_module, _function, _args}), do: false
    defp static_default?(_default), do: true

    @spec blank_subject(Ash.Resource.t(), Actions.action()) ::
            Ash.Query.t() | Ash.Changeset.t() | Ash.ActionInput.t()
    defp blank_subject(resource, %{type: :read}), do: Ash.Query.new(resource)
    defp blank_subject(resource, %{type: :create}), do: Ash.Changeset.new(resource)
    defp blank_subject(resource, %{type: :update}), do: Ash.Changeset.new(struct(resource))

    defp blank_subject(resource, %{type: :destroy}),
      do: %{Ash.Changeset.new(struct(resource)) | action_type: :destroy}

    # Generic actions (`action :name do ... end`), e.g. one run by a Reactor.
    defp blank_subject(resource, %{type: :action}), do: Ash.ActionInput.new(resource)
  end
end
