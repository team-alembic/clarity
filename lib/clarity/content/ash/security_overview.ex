with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Content.Ash.SecurityOverview do
    @moduledoc """
    Security-lens content provider for Ash domains and resources.

    Unlike the `*Overview` providers, which restate declarations, this provider
    only applies under the Security lens and surfaces *emergent* authorisation
    facts that are not visible in any single source file: per-action policy
    coverage, effective outcomes, and field-level exposure.

    Findings, not verdicts: every item is a fact plus why it might matter. Ash
    has legitimate reasons for each pattern, so the reviewer decides.
    """

    @behaviour Clarity.Content

    alias Ash.Policy.Policy
    alias Ash.Resource.Actions
    alias Ash.Resource.Info
    alias Clarity.Perspective.Lens
    alias Clarity.Vertex.Ash.Domain
    alias Clarity.Vertex.Ash.Resource
    alias Clarity.Vertex.Util

    @authorizer Ash.Policy.Authorizer

    @impl Clarity.Content
    def name, do: "Security"

    @impl Clarity.Content
    def description, do: "Authorisation posture, policy coverage, and exposure"

    @impl Clarity.Content
    def sort_priority, do: -110

    @impl Clarity.Content
    def applies?(%Domain{}, %Lens{id: "security"}), do: true
    def applies?(%Resource{}, %Lens{id: "security"}), do: true
    def applies?(_vertex, _lens), do: false

    @impl Clarity.Content
    def render_static(%Domain{domain: domain}, _lens) do
      {:markdown, fn _props -> domain_markdown(domain) end}
    end

    def render_static(%Resource{resource: resource}, _lens) do
      {:markdown, fn _props -> resource_markdown(resource) end}
    end

    @spec domain_markdown(Ash.Domain.t()) :: iodata()
    defp domain_markdown(domain) do
      resources = Ash.Domain.Info.resources(domain)

      [
        "# Security Posture\n\n",
        authorisation_mode_section(domain),
        unprotected_resources_section(resources),
        bypass_resources_section(resources)
      ]
    end

    @spec authorisation_mode_section(Ash.Domain.t()) :: iodata()
    defp authorisation_mode_section(domain) do
      mode = Ash.Domain.Info.authorize(domain)
      require_actor? = Ash.Domain.Info.require_actor?(domain)

      [
        "## Authorisation Mode\n\n",
        "| Setting | Value |\n| --- | --- |\n",
        "| **Authorize** | `",
        inspect(mode),
        "` |\n",
        "| **Require actor?** | ",
        to_string(require_actor?),
        " |\n\n",
        case mode do
          :when_requested ->
            "> ⚠ Policies run **only** when the caller passes `authorize?: true`. " <>
              "Any call that does not is unrestricted.\n\n"

          _ ->
            []
        end
      ]
    end

    @spec unprotected_resources_section([Ash.Resource.t()]) :: iodata()
    defp unprotected_resources_section(resources) do
      unprotected = Enum.reject(resources, &authorized?/1)

      [
        "## Policy Enforcement\n\n",
        "#{length(resources) - length(unprotected)} of #{length(resources)} resources enforce policies.\n\n",
        case unprotected do
          [] ->
            "All resources have a policy authorizer.\n\n"

          _ ->
            [
              "Resources with **no policy authorizer** (access not restricted by Ash policies):\n\n",
              Enum.map(unprotected, &["- ", resource_link(&1), "\n"]),
              "\n"
            ]
        end
      ]
    end

    @spec bypass_resources_section([Ash.Resource.t()]) :: iodata()
    defp bypass_resources_section(resources) do
      with_bypass = Enum.filter(resources, &Enum.any?(policies(&1), fn p -> p.bypass? end))

      case with_bypass do
        [] ->
          []

        _ ->
          [
            "## Bypass Policies\n\n",
            "These resources carry bypass policies (a passing bypass skips all other policies):\n\n",
            Enum.map(with_bypass, &["- ", resource_link(&1), "\n"]),
            "\n"
          ]
      end
    end

    @spec resource_markdown(Ash.Resource.t()) :: iodata()
    defp resource_markdown(resource) do
      [
        "# Security Posture\n\n",
        posture_section(resource),
        action_coverage_section(resource),
        field_exposure_section(resource)
      ]
    end

    @spec posture_section(Ash.Resource.t()) :: iodata()
    defp posture_section(resource) do
      policies = policies(resource)
      bypasses = Enum.count(policies, & &1.bypass?)

      [
        "## Enforcement\n\n",
        if authorized?(resource) do
          [
            "| Property | Value |\n| --- | --- |\n",
            "| **Authorizer** | `Ash.Policy.Authorizer` |\n",
            "| **Policies** | ",
            to_string(length(policies)),
            " |\n",
            "| **Bypass policies** | ",
            to_string(bypasses),
            " |\n\n"
          ]
        else
          "> ⚠ **No policy authorizer.** Ash policies do not restrict access to " <>
            "this resource — every action is allowed (subject to the domain's " <>
            "authorisation mode).\n\n"
        end
      ]
    end

    @spec action_coverage_section(Ash.Resource.t()) :: iodata()
    defp action_coverage_section(resource) do
      policies = policies(resource)
      authorized? = authorized?(resource)

      [
        "## Action Coverage\n\n",
        "Which policies govern each action, and the effective outcome for a " <>
          "non-bypass actor. Computed by resolving each policy's condition " <>
          "against the action.\n\n",
        "| Action | Type | Governed by | Effective |\n| --- | --- | --- | --- |\n",
        Enum.map(Info.actions(resource), &action_row(&1, resource, policies, authorized?)),
        "\n"
      ]
    end

    @spec action_row(Actions.action(), Ash.Resource.t(), [Policy.t()], boolean()) ::
            iodata()
    defp action_row(action, resource, policies, authorized?) do
      applying = Enum.filter(policies, &(policy_applies?(&1, action) == :applies))
      non_bypass = Enum.reject(applying, & &1.bypass?)
      unknown? = Enum.any?(policies, &(policy_applies?(&1, action) == :unknown))

      {governed_by, effective} =
        cond do
          not authorized? -> {"—", "Unrestricted (no authorizer)"}
          non_bypass != [] -> {"#{length(applying)} policy(s)", "Governed"}
          applying != [] -> {"bypass only", "⚠ Forbidden by default unless bypass passes"}
          unknown? -> {"runtime condition", "Conditional (runtime checks)"}
          true -> {"none", "⚠ Forbidden by default (no matching policy)"}
        end

      [
        "| [",
        Atom.to_string(action.name),
        "](vertex://",
        Util.id(Clarity.Vertex.Ash.Action, [resource, action.name]),
        ")",
        " | `",
        Atom.to_string(action.type),
        "`",
        " | ",
        governed_by,
        " | ",
        effective,
        " |\n"
      ]
    end

    @spec field_exposure_section(Ash.Resource.t()) :: iodata()
    defp field_exposure_section(resource) do
      sensitive = Enum.filter(Info.attributes(resource), & &1.sensitive?)

      case sensitive do
        [] ->
          []

        _ ->
          [
            "## Sensitive Field Exposure\n\n",
            "Attributes marked `sensitive?`. A sensitive attribute that is also " <>
              "`public?` with no field policy covering it is exposed wherever the " <>
              "resource is rendered.\n\n",
            "| Attribute | Public? | Field policy? | |\n| --- | --- | --- | --- |\n",
            Enum.map(sensitive, &sensitive_row(&1, resource)),
            "\n"
          ]
      end
    end

    @spec sensitive_row(Ash.Resource.Attribute.t(), Ash.Resource.t()) :: iodata()
    defp sensitive_row(attribute, resource) do
      covered? =
        Ash.Policy.Info.field_policies_for_field(resource, attribute.name) not in [nil, []]

      exposed? = attribute.public? and not covered?

      [
        "| [",
        Atom.to_string(attribute.name),
        "](vertex://",
        Util.id(Clarity.Vertex.Ash.Attribute, [resource, attribute.name]),
        ")",
        " | ",
        to_string(attribute.public?),
        " | ",
        to_string(covered?),
        " | ",
        if(exposed?, do: "⚠ exposed", else: "protected"),
        " |\n"
      ]
    end

    @spec policy_applies?(Policy.t(), Actions.action()) ::
            :applies | :excluded | :unknown
    defp policy_applies?(policy, action) do
      policy.condition
      |> List.wrap()
      |> Enum.reduce(:applies, fn check, acc -> combine(acc, condition_decides(check, action)) end)
    end

    @spec combine(:applies | :excluded | :unknown, :applies | :excluded | :unknown) ::
            :applies | :excluded | :unknown
    defp combine(:excluded, _), do: :excluded
    defp combine(_, :excluded), do: :excluded
    defp combine(:unknown, _), do: :unknown
    defp combine(_, :unknown), do: :unknown
    defp combine(:applies, :applies), do: :applies

    @spec condition_decides(term(), Actions.action()) ::
            :applies | :excluded | :unknown
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

    @spec authorized?(Ash.Resource.t()) :: boolean()
    defp authorized?(resource), do: @authorizer in Info.authorizers(resource)

    @spec policies(Ash.Resource.t()) :: [Policy.t()]
    defp policies(resource), do: Ash.Policy.Info.policies(resource)

    @spec resource_link(Ash.Resource.t()) :: iodata()
    defp resource_link(resource) do
      ["[", inspect(resource), "](vertex://", Util.id(Resource, [resource]), ")"]
    end
  end
end
