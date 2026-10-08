with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Report.SecurityPosture do
    @moduledoc """
    Security posture report: how the Ash resources are protected — which actor
    can reach which action, solved by Ash's own policies, and each resource's
    policies, bypasses and exposed sensitive fields.

    Its actions (`actions/2`), most urgent first: sensitive fields anyone can
    read, domains that check policies only when asked, resources with no
    policies, actions anonymous callers can reach, sensitive fields without
    field policies, and bypasses to review.
    """

    @behaviour Clarity.Report

    use Clarity.Web, :live_component

    alias Ash.Policy.Info, as: PolicyInfo
    alias Ash.Resource.Info
    alias Clarity.Ash.PolicyAnalysis
    alias Clarity.Graph
    alias Clarity.Report.Action
    alias Clarity.Report.Charts
    alias Clarity.Report.Components
    alias Clarity.Vertex
    alias Clarity.Vertex.Ash.Attribute
    alias Clarity.Vertex.Ash.Domain
    alias Clarity.Vertex.Ash.Resource
    alias Clarity.Vertex.Util
    alias Phoenix.LiveView.Rendered

    @authorizer Ash.Policy.Authorizer

    @typep finding() :: %{
             name: String.t(),
             short_name: String.t(),
             module: module(),
             id: String.t(),
             domain: String.t(),
             domain_id: String.t() | nil,
             governed?: boolean(),
             bypass?: boolean(),
             exposed: [String.t()],
             actions: [String.t()],
             reach: %{String.t() => [String.t()]},
             anon_read?: boolean(),
             anon_open: [String.t()],
             anon_conditional: [String.t()],
             anon_verdicts: [PolicyAnalysis.verdict()]
           }

    @typedoc "What the report shows, from `analyse/1`."
    @type analysis() :: %{
            resources: [finding()],
            lax_domains: [%{name: String.t(), id: String.t()}],
            actors: [String.t()]
          }

    @impl Clarity.Report
    def name, do: "Security posture"

    @impl Clarity.Report
    def description,
      do: "Authorisation posture, action reachability, and sensitive-field exposure"

    @impl Clarity.Report
    def category, do: "Security"

    @impl Clarity.Report
    def actions(graph, _opts) do
      resources = analyse(graph).resources

      Enum.reject(
        [
          anyone_reads(Enum.filter(resources, &(&1.exposed != [] and &1.anon_read?))),
          lax(lax_domains(graph)),
          ungoverned(Enum.reject(resources, & &1.governed?)),
          anon_reachable(
            Enum.filter(
              resources,
              &(&1.governed? and (&1.anon_open != [] or &1.anon_conditional != []))
            )
          ),
          signed_in_reads(Enum.filter(resources, &(&1.exposed != [] and not &1.anon_read?))),
          bypassed(Enum.filter(resources, & &1.bypass?))
        ],
        &is_nil/1
      )
    end

    @spec anyone_reads([finding()]) :: Action.t() | nil
    defp anyone_reads([]), do: nil

    defp anyone_reads(findings) do
      %Action{
        severity: :high,
        title: "Sensitive fields anyone can read",
        hint:
          "Sensitive and public, with no field policy, on a resource anyone can read without signing in.",
        fix: "Add a field policy for each, or make it private with `public? false`.",
        groups: Enum.map(findings, &field_group/1)
      }
    end

    @spec lax([%{name: String.t(), id: String.t()}]) :: Action.t() | nil
    defp lax([]), do: nil

    defp lax(domains) do
      %Action{
        severity: :high,
        title: "Domains that check policies only when asked",
        hint:
          "With authorize :when_requested, a call that doesn't pass authorize?: true runs unchecked.",
        fix:
          "Set `authorize :by_default` in each domain's `authorization` block, so every call is checked unless it opts out.",
        groups: [%{items: Enum.map(domains, &%{text: &1.name, id: &1.id})}]
      }
    end

    @spec ungoverned([finding()]) :: Action.t() | nil
    defp ungoverned([]), do: nil

    defp ungoverned(findings) do
      %Action{
        severity: :medium,
        title: "Resources with no policies",
        hint: "Without the policy authorizer, any caller can run every action.",
        fix:
          "Add `authorizers: [Ash.Policy.Authorizer]` to each and write policies for its actions.",
        groups:
          for {{domain, domain_id}, findings} <- by_domain(findings) do
            %{
              label: domain,
              id: domain_id,
              items: Enum.map(findings, &%{text: &1.short_name, id: &1.id})
            }
          end
      }
    end

    @spec anon_reachable([finding()]) :: Action.t() | nil
    defp anon_reachable([]), do: nil

    defp anon_reachable(findings) do
      %Action{
        severity: :medium,
        title: "Actions anonymous callers can reach",
        hint:
          "Callers who haven't signed in can run these; faded ones depend on a runtime check.",
        fix:
          "Check each is meant to be public; if not, require an actor, e.g. `authorize_if actor_present()`.",
        groups:
          for finding <- findings do
            %{
              label: finding.name,
              id: finding.id,
              items:
                Enum.map(finding.anon_open, &action_item(finding, &1)) ++
                  Enum.map(
                    finding.anon_conditional,
                    &Map.merge(action_item(finding, &1), %{
                      muted?: true,
                      hint: "Depends on a runtime check"
                    })
                  )
            }
          end
      }
    end

    @spec signed_in_reads([finding()]) :: Action.t() | nil
    defp signed_in_reads([]), do: nil

    defp signed_in_reads(findings) do
      %Action{
        severity: :low,
        title: "Sensitive fields without field policies",
        hint: "Any actor who can read the resource can read these fields.",
        fix: "Add field policies if not every reader should see them.",
        groups: Enum.map(findings, &field_group/1)
      }
    end

    @spec bypassed([finding()]) :: Action.t() | nil
    defp bypassed([]), do: nil

    defp bypassed(findings) do
      %Action{
        severity: :low,
        title: "Bypass policies to review",
        hint: "A bypass that passes skips every other policy.",
        fix: "Check each bypass lets through only who it should.",
        groups: [%{items: Enum.map(findings, &%{text: &1.name, id: &1.id})}]
      }
    end

    @spec field_group(finding()) :: Action.group()
    defp field_group(finding) do
      %{
        label: finding.name,
        id: finding.id,
        items:
          Enum.map(finding.exposed, &%{text: &1, id: Util.id(Attribute, [finding.module, &1])})
      }
    end

    @spec action_item(finding(), String.t()) :: Action.item()
    defp action_item(finding, action),
      do: %{text: action, id: Util.id(Clarity.Vertex.Ash.Action, [finding.module, action])}

    # Solving every action's policies for each actor grows with the app, so it
    # runs asynchronously: the page shows at once, and the analysis follows.
    # (Async work only starts once the socket connects, so the first, static
    # render doesn't pay for it.)
    @impl Phoenix.LiveComponent
    def update(assigns, socket) do
      graph = assigns.graph

      {:ok,
       socket
       |> assign(prefix: assigns.prefix, lens: assigns.lens)
       |> assign_async(:analysis, fn -> {:ok, %{analysis: analyse(graph)}} end)}
    end

    @impl Phoenix.LiveComponent
    def render(assigns) do
      ~H"""
      <section>
        <.async_result :let={analysis} assign={@analysis}>
          <:loading>
            <p class="report-status-meta">Analysing each resource's policies…</p>
          </:loading>
          <:failed>
            <p class="text-sm text-base-light-600 dark:text-base-dark-400">
              Clarity could not analyse the policies.
            </p>
          </:failed>

          <.posture analysis={analysis} prefix={@prefix} lens={@lens} />
        </.async_result>
      </section>
      """
    end

    attr :analysis, :map, required: true, doc: "From `analyse/1`"
    attr :prefix, :string, required: true
    attr :lens, :any, required: true

    @doc "The report, from its `analyse/1`."
    @spec posture(map()) :: Rendered.t()
    def posture(assigns) do
      assigns =
        assign(assigns, resources: assigns.analysis.resources, actors: assigns.analysis.actors)

      ~H"""
      <div class="space-y-6">
        <p :if={@resources == []} class="report-status-meta">No Ash resources found.</p>

        <div :if={@resources != []} class="grid grid-cols-2 gap-2 sm:grid-cols-4">
          <Charts.stat label="Resources" value={length(@resources)} />
          <Charts.stat
            label="Without policies"
            value={Enum.count(@resources, &(not &1.governed?))}
            tone={if(Enum.any?(@resources, &(not &1.governed?)), do: :warning, else: :ok)}
          />
          <Charts.stat
            label="Actions open to anyone"
            value={anon_open_count(@resources)}
            tone={if(anon_open_count(@resources) > 0, do: :warning, else: :ok)}
          />
          <Charts.stat
            label="Sensitive fields exposed"
            value={exposed_count(@resources)}
            tone={if(exposed_count(@resources) > 0, do: :error, else: :neutral)}
          />
        </div>

        <Components.section
          :if={@resources != []}
          id="reach"
          title="Who can reach what"
          count={length(@resources)}
        >
          <table class="report-table">
            <thead>
              <tr>
                <th>Resource</th>
                <th :for={actor <- @actors}>{actor}</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={finding <- @resources}>
                <td><.resource finding={finding} prefix={@prefix} lens={@lens} /></td>
                <td :for={actor <- @actors}>
                  <.reach actions={Map.get(finding.reach, actor, [])} all={finding.actions} />
                </td>
              </tr>
            </tbody>
          </table>
        </Components.section>

        <Components.section
          :if={@resources != []}
          id="resources"
          title="Resources"
          count={length(@resources)}
        >
          <table class="report-table">
            <thead>
              <tr>
                <th>Resource</th>
                <th>Domain</th>
                <th>Policies</th>
                <th>Bypass</th>
                <th>Sensitive fields exposed</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={finding <- @resources}>
                <td><.resource finding={finding} prefix={@prefix} lens={@lens} /></td>
                <td>{finding.domain}</td>
                <td>
                  <span :if={finding.governed?} class="report-tag" data-tone="ok">Yes</span>
                  <span :if={!finding.governed?} class="report-tag" data-tone="warning">None</span>
                </td>
                <td>
                  <span :if={finding.bypass?} class="report-tag">Bypass</span>
                  <span :if={!finding.bypass?} class="report-muted">—</span>
                </td>
                <td>
                  <span :if={finding.exposed == []} class="report-muted">—</span>
                  <span :if={finding.exposed != []} class="flex flex-wrap gap-1">
                    <Components.chip :for={field <- finding.exposed}>{field}</Components.chip>
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
        </Components.section>
      </div>
      """
    end

    attr :finding, :map, required: true
    attr :prefix, :string, required: true
    attr :lens, :any, required: true

    @spec resource(map()) :: Rendered.t()
    defp resource(assigns) do
      ~H"""
      <.link patch={Components.path(@prefix, @lens, @finding.id)} class="report-link">
        {@finding.name}
      </.link>
      """
    end

    attr :actions, :list, required: true
    attr :all, :list, required: true

    # The actions an actor can reach: "all" or "none" rather than a full list.
    @spec reach(map()) :: Rendered.t()
    defp reach(%{actions: []} = assigns), do: ~H|<span class="report-muted">none</span>|

    defp reach(%{actions: actions, all: actions} = assigns),
      do: ~H|<span class="report-tag">all {length(@all)}</span>|

    defp reach(assigns) do
      ~H"""
      <span class="flex flex-wrap gap-1">
        <Components.chip :for={action <- @actions}>{action}</Components.chip>
      </span>
      """
    end

    @spec anon_open_count([finding()]) :: non_neg_integer()
    defp anon_open_count(resources) do
      resources
      |> Enum.flat_map(& &1.anon_verdicts)
      |> Enum.count(&(&1 in [:always, :unrestricted]))
    end

    @spec exposed_count([finding()]) :: non_neg_integer()
    defp exposed_count(findings), do: Enum.sum_by(findings, &length(&1.exposed))

    @spec by_domain([finding()]) :: [{{String.t(), String.t() | nil}, [finding()]}]
    defp by_domain(findings) do
      findings |> Enum.group_by(&{&1.domain, &1.domain_id}) |> Enum.sort_by(&elem(elem(&1, 0), 0))
    end

    @doc false
    @spec analyse(Graph.t()) :: analysis()
    def analyse(graph) do
      resources = findings(graph)

      %{
        resources: resources,
        lax_domains: lax_domains(graph),
        actors: resources |> Enum.flat_map(&Map.keys(&1.reach)) |> Enum.uniq() |> Enum.sort()
      }
    end

    @spec findings(Graph.t()) :: [finding()]
    defp findings(graph) do
      graph
      |> Graph.vertices({:==, :vertex_type, Resource})
      |> Enum.map(&finding/1)
      |> Enum.sort_by(& &1.name)
    end

    @spec finding(Resource.t()) :: finding()
    defp finding(%Resource{resource: resource} = vertex) do
      actions = Info.actions(resource)
      profiles = PolicyAnalysis.actor_profiles(resource)
      verdicts = verdicts(resource, actions, profiles)
      sensitive = Enum.filter(Info.attributes(resource), & &1.sensitive?)
      anon_verdicts = Enum.map(actions, &Map.fetch!(verdicts, {&1.name, nil}))

      %{
        name: Vertex.Name.in_app(resource),
        short_name: short_name(resource),
        module: resource,
        id: Vertex.id(vertex),
        domain: domain_name(resource),
        domain_id: resource |> Info.domain() |> then(&(&1 && Util.id(Domain, [&1]))),
        governed?: @authorizer in Info.authorizers(resource),
        bypass?: Enum.any?(PolicyInfo.policies(resource), & &1.bypass?),
        exposed:
          sensitive |> Enum.filter(&exposed?(resource, &1)) |> Enum.map(&to_string(&1.name)),
        actions: Enum.map(actions, &to_string(&1.name)),
        reach: reach(actions, profiles, verdicts),
        anon_read?: anon_read?(actions, verdicts),
        anon_open: anon_actions(actions, verdicts, :always),
        anon_conditional: anon_actions(actions, verdicts, :conditional),
        anon_verdicts: anon_verdicts
      }
    end

    # Each action's verdict for each distinct actor (the anonymous one, `nil`,
    # always included), solved once and shared by every view of the resource.
    @spec verdicts(Ash.Resource.t(), [term()], [{String.t(), PolicyAnalysis.actor()}]) ::
            %{{atom(), PolicyAnalysis.actor()} => PolicyAnalysis.verdict()}
    defp verdicts(resource, actions, profiles) do
      actors = Enum.uniq([nil | Enum.map(profiles, &elem(&1, 1))])

      for action <- actions, actor <- actors, into: %{} do
        {{action.name, actor}, PolicyAnalysis.action_verdict(resource, action, actor)}
      end
    end

    @spec reach([term()], [{String.t(), PolicyAnalysis.actor()}], map()) ::
            %{String.t() => [String.t()]}
    defp reach(actions, profiles, verdicts) do
      Map.new(profiles, fn {label, actor} ->
        reachable =
          actions
          |> Enum.filter(&(Map.fetch!(verdicts, {&1.name, actor}) != :never))
          |> Enum.map(&to_string(&1.name))

        {label, reachable}
      end)
    end

    # The actions an anonymous caller gets the given verdict for.
    @spec anon_actions([term()], map(), PolicyAnalysis.verdict()) :: [String.t()]
    defp anon_actions(actions, verdicts, verdict) do
      for action <- actions,
          Map.fetch!(verdicts, {action.name, nil}) == verdict,
          do: to_string(action.name)
    end

    @spec anon_read?([term()], map()) :: boolean()
    defp anon_read?(actions, verdicts) do
      actions
      |> Enum.filter(&(&1.type == :read))
      |> Enum.any?(&(Map.fetch!(verdicts, {&1.name, nil}) != :never))
    end

    # Domains that run policies only when a call passes `authorize?: true`.
    @spec lax_domains(Graph.t()) :: [%{name: String.t(), id: String.t()}]
    defp lax_domains(graph) do
      graph
      |> Graph.vertices({:==, :vertex_type, Domain})
      |> Enum.filter(&(Ash.Domain.Info.authorize(&1.domain) == :when_requested))
      |> Enum.map(&%{name: Vertex.Name.in_app(&1.domain), id: Vertex.id(&1)})
      |> Enum.sort_by(& &1.name)
    end

    # Within its domain, for when its domain is shown beside it.
    @spec short_name(Ash.Resource.t()) :: String.t()
    defp short_name(resource) do
      case Info.domain(resource) do
        nil -> Vertex.Name.in_app(resource)
        domain -> Vertex.Name.within(resource, domain)
      end
    end

    @spec domain_name(Ash.Resource.t()) :: String.t()
    defp domain_name(resource) do
      case Info.domain(resource) do
        nil -> "—"
        domain -> Vertex.Name.in_app(domain)
      end
    end

    @spec exposed?(Ash.Resource.t(), Ash.Resource.Attribute.t()) :: boolean()
    defp exposed?(resource, attribute) do
      attribute.public? and
        PolicyInfo.field_policies_for_field(resource, attribute.name) in [nil, []]
    end
  end
end
