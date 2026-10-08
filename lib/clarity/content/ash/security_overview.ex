with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Content.Ash.SecurityOverview do
    @moduledoc """
    Security-lens content provider for Ash domains and resources.

    Unlike the `*Overview` providers, which restate declarations, this provider
    only applies under the Security lens and surfaces *emergent* authorisation
    facts that are not visible in any single source file: per-action policy
    coverage, effective outcomes, and field-level exposure.

    A domain's leads with its posture, how many of its resources enforce
    policies, and its authorisation mode, then a card per resource: those that
    enforce no policies first, then those that do, with how many of their
    actions each kind of actor can reach. A resource's leads with what
    enforces it, then which actor reaches which action, its policies and its
    sensitive fields.

    Findings, not verdicts: every item is a fact plus why it might matter. Ash
    has legitimate reasons for each pattern, so the reviewer decides.
    """

    @behaviour Clarity.Content

    use Clarity.Web, :live_component

    import Clarity.Components.OverviewComponents
    import Clarity.Content.Ash.Overview

    alias Ash.Resource.Info
    alias Clarity.Ash.PolicyAnalysis
    alias Clarity.Perspective.Lens
    alias Clarity.Vertex
    alias Clarity.Vertex.Ash.Domain
    alias Clarity.Vertex.Ash.Policy
    alias Clarity.Vertex.Ash.Resource
    alias Phoenix.LiveView.Rendered

    @authorizer Ash.Policy.Authorizer
    @action_types [:create, :read, :update, :destroy, :action]

    # How a domain's authorisation mode reads, and why it matters.
    @modes %{
      by_default:
        {"authorizes by default", :good,
         "Policies run unless a call opts out with authorize?: false"},
      always: {"always authorizes", :good, "Policies always run: no call can opt out"},
      when_requested:
        {"authorizes when asked", :danger,
         "Policies run only when a call passes authorize?: true; any other call is unrestricted"}
    }

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

    @impl Phoenix.LiveComponent
    def update(assigns, socket) do
      {:ok,
       socket
       |> assign(assigns)
       |> assign(links: links(assigns))
       |> assign(posture(assigns.vertex))}
    end

    @impl Phoenix.LiveComponent
    def render(%{vertex: %Domain{}} = assigns) do
      ~H"""
      <div class="ov-page" id={@id}>
        <div class="ov-head">
          <.hero vertex={@vertex} kind="Domain">
            <:badge>
              <.flag text={elem(@mode, 0)} kind={elem(@mode, 1)} hint={elem(@mode, 2)} />
            </:badge>
            <:badge>
              <.flag
                :if={@require_actor?}
                text="actor required"
                kind={:good}
                hint="Every call must name an actor"
              />
              <.flag
                :if={not @require_actor?}
                text="actor optional"
                hint="Calls may run without an actor"
              />
            </:badge>
            <:headline>
              <span class="ov-phrase">
                <b>{@protected} of {length(@resources)}</b> resources enforce policies
              </span>
            </:headline>
            <.meter value={@protected} total={length(@resources)} />
          </.hero>

          <.callout :if={elem(@mode, 1) == :danger} kind={:danger}>
            Policies run <b>only</b> when the caller passes <code>authorize?: true</code>.
            Any call that doesn't is unrestricted.
          </.callout>
        </div>

        <.section
          :if={@unprotected != []}
          id="unprotected"
          title="Enforcing no policies"
          icon="advisory"
          tone="warning"
          count={length(@unprotected)}
        >
          <p class="ov-muted mb-2">
            No policy authorizer: Ash policies don't restrict their actions.
          </p>
          <div class="ov-cards">
            <.security_card :for={summary <- @unprotected} links={@links} summary={summary} />
          </div>
        </.section>

        <.section
          :if={@enforcing != []}
          id="enforcing"
          title="Enforcing policies"
          icon="policy"
          tone="rule"
          count={length(@enforcing)}
        >
          <div class="ov-cards">
            <.security_card :for={summary <- @enforcing} links={@links} summary={summary} />
          </div>
        </.section>
      </div>
      """
    end

    def render(%{vertex: %Resource{}} = assigns) do
      ~H"""
      <div class="ov-page" id={@id}>
        <div class="ov-head">
          <.hero vertex={@vertex} kind="Resource">
            <:badge>
              <.security_flags links={@links} summary={@summary} />
            </:badge>
            <:headline :if={@summary.protected?}>
              <.reach_line summary={@summary} />
            </:headline>
          </.hero>

          <.callout :if={not @summary.protected?} kind={:warn}>
            <b>No policy authorizer.</b>
            Ash policies don't restrict this resource: every action is allowed,
            as far as the domain's authorisation mode lets it be.
          </.callout>

          <.facts :if={@summary.protected?}>
            <:fact label="Policies">{@summary.policies}</:fact>
            <:fact label="Bypass policies">{@summary.bypasses}</:fact>
            <:fact label="Field policies">{@field_policies}</:fact>
            <:fact :if={@sensitive != []} label="Sensitive fields">
              {length(@sensitive)}
              <span :if={@summary.exposed > 0} class="ov-muted">({@summary.exposed} exposed)</span>
            </:fact>
          </.facts>
        </div>

        <.section
          :if={@summary.protected?}
          id="reachability"
          title="Who can reach each action"
          icon="action"
          tone="behaviour"
          count={length(@actions)}
        >
          <p class="ov-muted mb-2 text-xs">
            Solved from the policies by Ash's SAT solver, for each kind of actor. Hover a verdict for what it means.
          </p>
          <.overview_table id="security-reachability" rows={@actions}>
            <:col :let={row} label="Action" class="w-0 whitespace-nowrap">
              <span class="inline-flex items-center gap-1.5">
                <.vertex_link
                  links={@links}
                  vertex={action(@resource, row.action)}
                  label={Atom.to_string(row.action.name)}
                  code
                />
                <span class="ov-muted text-xs">{row.action.type}</span>
              </span>
            </:col>
            <:col :let={row} :for={{label, index} <- Enum.with_index(@profiles)} label={label}>
              <.flag text={Atom.to_string(Enum.at(row.verdicts, index))} />
            </:col>
          </.overview_table>
        </.section>

        <.section
          :if={@policies != []}
          id="policies"
          title="Policies"
          icon="policy"
          tone="rule"
          count={length(@policies)}
        >
          <ul class="ov-steps">
            <li :for={policy <- @policies}>
              <.vertex_link links={@links} vertex={policy} />
              <.flag :if={policy.policy.bypass?} text="bypass" />
              <span :if={detail(policy)} class="ov-muted text-xs">{detail(policy)}</span>
            </li>
          </ul>
        </.section>

        <.section
          :if={@sensitive != []}
          id="sensitive"
          title="Sensitive fields"
          icon="attribute"
          tone="data"
          count={length(@sensitive)}
        >
          <.overview_table id="security-sensitive" rows={@sensitive}>
            <:col :let={field} label="Attribute" class="w-0 whitespace-nowrap">
              <.vertex_link
                links={@links}
                vertex={attribute(@resource, field.attribute)}
                label={Atom.to_string(field.attribute.name)}
                code
              />
            </:col>
            <:col :let={field} label="Exposure">
              <div class="ov-flags">
                <.flag :if={field.exposed?} text="exposed" />
                <.flag :if={not field.exposed?} text="protected" />
                <.flag text={if field.attribute.public?, do: "public", else: "private"} />
                <.flag
                  :if={field.covered?}
                  text="field policy"
                  kind={:good}
                  hint="A field policy decides who may read it"
                />
              </div>
            </:col>
          </.overview_table>
        </.section>
      </div>
      """
    end

    # A resource on its domain's page: what enforces it, and who reaches how
    # much of it.
    attr :links, :map, required: true
    attr :summary, :map, required: true

    @spec security_card(map()) :: Rendered.t()
    defp security_card(assigns) do
      assigns = assign(assigns, :vertex, %Resource{resource: assigns.summary.resource})

      ~H"""
      <article class="ov-card ov-resource-card">
        <div class="flex items-start gap-1.5">
          <.vertex_link
            links={@links}
            vertex={@vertex}
            label={@summary.resource |> Module.split() |> List.last()}
            class="min-w-0"
          />
          <div class="ov-flags ml-auto justify-end">
            <.security_flags links={@links} summary={@summary} />
          </div>
        </div>
        <div :if={@summary.protected?} class="ov-reach">
          <.reach :for={reach <- @summary.reach} reach={reach} />
        </div>
        <p :if={not @summary.protected?} class="ov-reach ov-muted text-xs">
          Every action allowed, as far as policies go.
        </p>
      </article>
      """
    end

    attr :links, :map, required: true
    attr :summary, :map, required: true

    @spec security_flags(map()) :: Rendered.t()
    defp security_flags(assigns) do
      ~H"""
      <.flag :if={not @summary.protected?} text="no policies" />
      <.vertex_pill
        :if={@summary.protected?}
        links={@links}
        vertex={%Resource{resource: @summary.resource}}
        label={"#{@summary.policies} #{if @summary.policies == 1, do: "policy", else: "policies"}"}
        icon="policy"
        tone="rule"
        to={policies_path(@links, @summary.resource)}
        hint={"Authorised by #{@summary.policies} #{if @summary.policies == 1, do: "policy", else: "policies"}: see them listed"}
      />
      <.flag
        :if={@summary.bypasses > 0}
        text="bypass"
        hint={"#{@summary.bypasses} bypass #{if @summary.bypasses == 1, do: "policy", else: "policies"}: a passing bypass skips the rest"}
      />
      <.flag
        :if={@summary.exposed > 0}
        text="exposed"
        hint={"#{@summary.exposed} sensitive #{if @summary.exposed == 1, do: "field is", else: "fields are"} public with no field policy"}
      />
      """
    end

    # How many of the resource's actions an actor reaches, coloured by the
    # worst of them: open to anyone, or only when checks pass.
    attr :reach, :map, required: true

    @spec reach(map()) :: Rendered.t()
    defp reach(assigns) do
      ~H"""
      <span
        class="ov-reach-actor"
        data-kind={reach_kind(@reach)}
        {Clarity.Tooltip.attrs(reach_hint(@reach))}
      >
        {@reach.label} <b>{@reach.reachable}/{@reach.total}</b>
      </span>
      """
    end

    attr :summary, :map, required: true

    @spec reach_line(map()) :: Rendered.t()
    defp reach_line(assigns) do
      ~H"""
      <span class="ov-phrase">
        <span class="ov-muted">Reachable actions:</span>
        <.reach :for={reach <- @summary.reach} reach={reach} />
      </span>
      """
    end

    @spec reach_kind(map()) :: String.t()
    defp reach_kind(%{open: open}) when open > 0, do: "danger"
    defp reach_kind(%{reachable: reachable}) when reachable > 0, do: "good"
    defp reach_kind(_reach), do: "muted"

    @spec reach_hint(map()) :: String.t()
    defp reach_hint(reach) do
      "#{reach.label}: #{reach.reachable} of #{reach.total} actions allowed" <>
        if(reach.open > 0, do: ", #{reach.open} whatever the checks", else: "")
    end

    # Everything a page shows, for a domain or a resource.
    @spec posture(Vertex.t()) :: map()
    defp posture(%Domain{domain: domain}) do
      summaries = domain |> Ash.Domain.Info.resources() |> Enum.map(&summary/1)

      %{
        mode:
          Map.get(
            @modes,
            Ash.Domain.Info.authorize(domain),
            {"authorize: #{Ash.Domain.Info.authorize(domain)}", :plain, nil}
          ),
        require_actor?: Ash.Domain.Info.require_actor?(domain),
        resources: summaries,
        protected: Enum.count(summaries, & &1.protected?),
        unprotected: Enum.reject(summaries, & &1.protected?),
        enforcing: Enum.filter(summaries, & &1.protected?)
      }
    end

    defp posture(%Resource{resource: resource}) do
      summary = summary(resource)
      profiles = if summary.protected?, do: PolicyAnalysis.actor_profiles(resource), else: []

      %{
        resource: resource,
        summary: summary,
        profiles: Enum.map(profiles, &elem(&1, 0)),
        actions:
          for action <- sorted_actions(resource) do
            %{
              action: action,
              verdicts:
                Enum.map(profiles, fn {_label, actor} ->
                  PolicyAnalysis.action_verdict(resource, action, actor)
                end)
            }
          end,
        policies: Enum.map(policies(resource), &%Policy{policy: &1, resource: resource}),
        field_policies: field_policy_count(resource),
        sensitive: sensitive_fields(resource)
      }
    end

    # What enforces a resource, how much of it each kind of actor reaches,
    # and how many of its sensitive fields are exposed.
    @spec summary(module()) :: map()
    defp summary(resource) do
      protected? = @authorizer in Info.authorizers(resource)
      policies = policies(resource)

      %{
        resource: resource,
        protected?: protected?,
        policies: length(policies),
        bypasses: Enum.count(policies, & &1.bypass?),
        exposed: resource |> sensitive_fields() |> Enum.count(& &1.exposed?),
        reach: if(protected?, do: reach_by_actor(resource), else: [])
      }
    end

    @spec reach_by_actor(module()) :: [map()]
    defp reach_by_actor(resource) do
      actions = Info.actions(resource)

      for {label, actor} <- PolicyAnalysis.actor_profiles(resource) do
        verdicts = Enum.map(actions, &PolicyAnalysis.action_verdict(resource, &1, actor))

        %{
          label: label,
          total: length(actions),
          reachable: Enum.count(verdicts, &(&1 in [:always, :unrestricted, :conditional])),
          open: Enum.count(verdicts, &(&1 in [:always, :unrestricted]))
        }
      end
    end

    @spec sorted_actions(module()) :: [Ash.Resource.Actions.action()]
    defp sorted_actions(resource) do
      resource
      |> Info.actions()
      |> Enum.sort_by(
        &{Enum.find_index(@action_types, fn type -> type == &1.type end), not &1.primary?}
      )
    end

    @spec sensitive_fields(module()) :: [map()]
    defp sensitive_fields(resource) do
      for attribute <- Info.attributes(resource), attribute.sensitive? do
        covered? =
          Ash.Policy.Info.field_policies_for_field(resource, attribute.name) not in [nil, []]

        %{attribute: attribute, covered?: covered?, exposed?: attribute.public? and not covered?}
      end
    end

    @spec field_policy_count(module()) :: non_neg_integer()
    defp field_policy_count(resource) do
      if @authorizer in Info.authorizers(resource),
        do: length(Ash.Policy.Info.field_policies(resource)),
        else: 0
    end

    @spec policies(module()) :: [Ash.Policy.Policy.t()]
    defp policies(resource) do
      if @authorizer in Info.authorizers(resource),
        do: Ash.Policy.Info.policies(resource),
        else: []
    end

    # The resource's policies, listed on its own Security tab.
    @spec policies_path(map(), module()) :: String.t()
    defp policies_path(links, resource),
      do: path(links, %Resource{resource: resource}) <> "#policies"

    @spec detail(Policy.t()) :: String.t() | nil
    defp detail(%Policy{policy: policy}), do: policy |> Policy.label() |> elem(1)
  end
end
