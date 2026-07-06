with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Report.SecurityPosture do
    @moduledoc """
    Security posture report: a written review of how each Ash resource under the
    security lens is protected — the domain authorisation mode, which actor can
    reach which action (solved by Ash's policies), policy enforcement, bypass
    policies, and sensitive-field exposure.

    Prose and tables explain what's going on and why it matters; these are
    findings, not verdicts.
    """

    @behaviour Clarity.Report

    use Clarity.Web, :live_component

    import Clarity.Components.MarkdownComponent

    alias Ash.Policy.Info, as: PolicyInfo
    alias Ash.Resource.Info
    alias Clarity.Ash.PolicyAnalysis
    alias Clarity.Graph
    alias Clarity.Perspective.Lens
    alias Clarity.Report.Charts
    alias Clarity.Vertex
    alias Clarity.Vertex.Ash.Domain
    alias Clarity.Vertex.Ash.Resource

    @authorizer Ash.Policy.Authorizer

    @typep finding() :: %{
             name: String.t(),
             domain: String.t(),
             governed?: boolean(),
             bypass?: boolean(),
             exposed: [String.t()],
             reach: %{String.t() => [String.t()]},
             anon_read?: boolean(),
             anon_verdicts: [PolicyAnalysis.verdict()]
           }

    @impl Clarity.Report
    def name, do: "Security posture"

    @impl Clarity.Report
    def description,
      do: "Authorisation posture, action reachability, and sensitive-field exposure"

    @impl Clarity.Report
    def applies?(%Lens{id: "security"}), do: true
    def applies?(_lens), do: false

    @impl Phoenix.LiveComponent
    def update(assigns, socket) do
      findings = findings(assigns.graph)
      modes = domain_modes(assigns.graph)

      {:ok,
       assign(socket,
         prefix: assigns.prefix,
         lens: assigns.lens,
         markdown: build_markdown(findings, modes),
         dashboard: dashboard(findings)
       )}
    end

    @impl Phoenix.LiveComponent
    def render(assigns) do
      ~H"""
      <section class="space-y-6">
        <div class="space-y-4">
          <h2 class="text-2xl font-bold">Security posture</h2>
          <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
            <Charts.stat label="Resources" value={@dashboard.resources} />
            <Charts.stat label="Open" value={@dashboard.open} tone={:warning} />
            <Charts.stat label="Bypass" value={@dashboard.bypass} tone={:info} />
            <Charts.stat label="Exposed fields" value={@dashboard.exposed} tone={:error} />
          </div>
          <div class="flex flex-wrap gap-8">
            <Charts.pie title="Policy coverage" segments={@dashboard.coverage} />
            <Charts.pie title="Anonymous reach" segments={@dashboard.reach} />
          </div>
        </div>

        <.markdown content={@markdown} prefix={@prefix} lens={@lens} class="max-w-[75ch]" />
      </section>
      """
    end

    @spec dashboard([finding()]) :: map()
    defp dashboard(findings) do
      total = length(findings)
      governed = Enum.count(findings, & &1.governed?)
      verdicts = Enum.flat_map(findings, & &1.anon_verdicts)
      open = Enum.count(verdicts, &(&1 in [:always, :unrestricted]))
      conditional = Enum.count(verdicts, &(&1 == :conditional))

      %{
        resources: total,
        open: total - governed,
        bypass: Enum.count(findings, & &1.bypass?),
        exposed: Enum.count(findings, &(&1.exposed != [])),
        coverage: [
          %{label: "Governed", value: governed, tone: :ok},
          %{label: "Open", value: total - governed, tone: :warning}
        ],
        reach: [
          %{label: "Open to anyone", value: open, tone: :error},
          %{label: "Conditional", value: conditional, tone: :warning},
          %{label: "Restricted", value: length(verdicts) - open - conditional, tone: :ok}
        ]
      }
    end

    @spec build_markdown([finding()], [{String.t(), atom()}]) :: iodata()
    defp build_markdown([], _modes) do
      "No Ash resources are visible under this lens, so there is no authorisation posture to report.\n\n"
    end

    defp build_markdown(findings, modes) do
      [
        "This report reviews how each Ash resource is protected. It surfaces facts that ",
        "aren't obvious from any single file: the domain authorisation mode, which actor can ",
        "reach which action, whether a bypass can skip policies, and whether sensitive fields ",
        "are exposed. These are *findings, not verdicts* — you decide what warrants attention.\n\n",
        overview(findings),
        authorisation_mode_section(modes),
        highest_risk_section(findings),
        reachability_section(findings),
        resources_section(findings)
      ]
    end

    @spec overview([finding()]) :: iodata()
    defp overview(findings) do
      total = length(findings)
      governed = Enum.count(findings, & &1.governed?)
      bypass = Enum.count(findings, & &1.bypass?)
      exposed = Enum.count(findings, &(&1.exposed != []))

      [
        "Clarity can see ",
        Integer.to_string(total),
        pluralize(total, " resource", " resources"),
        ". ",
        Integer.to_string(governed),
        " of them ",
        pluralize(governed, "enforces", "enforce"),
        " policies; the rest are open. ",
        Integer.to_string(bypass),
        pluralize(bypass, " carries a bypass", " carry a bypass"),
        ", and ",
        Integer.to_string(exposed),
        pluralize(exposed, " exposes sensitive fields", " expose sensitive fields"),
        ".\n\n"
      ]
    end

    @spec authorisation_mode_section([{String.t(), atom()}]) :: iodata()
    defp authorisation_mode_section(modes) do
      lax = for {name, :when_requested} <- modes, do: name

      [
        "### Authorisation mode\n\n",
        case lax do
          [] ->
            "Every domain enforces policies by default.\n\n"

          names ->
            [
              "⚠ ",
              to_sentence(Enum.map(names, &"**#{&1}**")),
              " ",
              pluralize(length(names), "runs", "run"),
              " policies **only** when a caller passes `authorize?: true` — any call that ",
              "doesn't is unrestricted. This is the single biggest posture lever; confirm it ",
              "is intended.\n\n"
            ]
        end
      ]
    end

    @spec highest_risk_section([finding()]) :: iodata()
    defp highest_risk_section(findings) do
      at_risk = Enum.filter(findings, &(&1.exposed != [] and &1.anon_read?))

      case at_risk do
        [] ->
          []

        rows ->
          [
            "### Highest risk\n\n",
            "These resources expose sensitive fields **and** their read is reachable without ",
            "authentication — sensitive data may be readable by anyone:\n\n",
            Enum.map(rows, fn f ->
              ["- **", f.name, "** exposes ", Enum.map_join(f.exposed, ", ", &"`#{&1}`"), "\n"]
            end),
            "\n"
          ]
      end
    end

    @spec reachability_section([finding()]) :: iodata()
    defp reachability_section(findings) do
      labels = findings |> Enum.flat_map(&Map.keys(&1.reach)) |> Enum.uniq() |> Enum.sort()

      [
        "### Action reachability\n\n",
        "Which actions each actor can reach, solved by Ash's policies. *Conditional* checks ",
        "(runtime or row-level) are treated as reachable. An empty cell means the actor cannot ",
        "reach any action.\n\n",
        "| Resource | ",
        Enum.join(labels, " | "),
        " |\n| --- | ",
        Enum.map_intersperse(labels, " | ", fn _ -> "---" end),
        " |\n",
        Enum.map(findings, &reachability_row(&1, labels)),
        "\n"
      ]
    end

    @spec reachability_row(finding(), [String.t()]) :: iodata()
    defp reachability_row(finding, labels) do
      cells =
        Enum.map_intersperse(labels, " | ", fn label ->
          case Map.get(finding.reach, label, []) do
            [] -> "—"
            actions -> Enum.join(actions, ", ")
          end
        end)

      ["| **", finding.name, "** | ", cells, " |\n"]
    end

    @spec resources_section([finding()]) :: iodata()
    defp resources_section(findings) do
      [
        "### Resources\n\n",
        "| Resource | Domain | Enforcement | Bypass | Sensitive exposed |\n",
        "| --- | --- | --- | --- | --- |\n",
        Enum.map(findings, &resource_row/1),
        "\n"
      ]
    end

    @spec resource_row(finding()) :: iodata()
    defp resource_row(finding) do
      [
        "| **",
        finding.name,
        "** | ",
        finding.domain,
        " | ",
        if(finding.governed?, do: "Governed", else: "⚠ Open"),
        " | ",
        if(finding.bypass?, do: "⚠ Bypass", else: "—"),
        " | ",
        case finding.exposed do
          [] -> "—"
          attrs -> Enum.map_join(attrs, ", ", &"`#{&1}`")
        end,
        " |\n"
      ]
    end

    @spec to_sentence([String.t()]) :: String.t()
    defp to_sentence([one]), do: one
    defp to_sentence([first, second]), do: "#{first} and #{second}"

    defp to_sentence(list) do
      {rest, [last]} = Enum.split(list, -1)
      "#{Enum.join(rest, ", ")}, and #{last}"
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
      sensitive = Enum.filter(Info.attributes(resource), & &1.sensitive?)
      anon_verdicts = Enum.map(actions, &PolicyAnalysis.action_verdict(resource, &1, nil))

      %{
        name: Vertex.name(vertex),
        domain: domain_name(resource),
        governed?: @authorizer in Info.authorizers(resource),
        bypass?: Enum.any?(PolicyInfo.policies(resource), & &1.bypass?),
        exposed:
          sensitive |> Enum.filter(&exposed?(resource, &1)) |> Enum.map(&to_string(&1.name)),
        reach: reach(resource, actions),
        anon_read?: anon_read?(resource, actions),
        anon_verdicts: anon_verdicts
      }
    end

    @spec reach(Ash.Resource.t(), [term()]) :: %{String.t() => [String.t()]}
    defp reach(resource, actions) do
      resource
      |> PolicyAnalysis.actor_profiles()
      |> Map.new(fn {label, actor} ->
        reachable =
          actions
          |> Enum.filter(&(PolicyAnalysis.action_verdict(resource, &1, actor) != :never))
          |> Enum.map(&to_string(&1.name))

        {label, reachable}
      end)
    end

    @spec anon_read?(Ash.Resource.t(), [term()]) :: boolean()
    defp anon_read?(resource, actions) do
      actions
      |> Enum.filter(&(&1.type == :read))
      |> Enum.any?(&(PolicyAnalysis.action_verdict(resource, &1, nil) != :never))
    end

    @spec domain_modes(Graph.t()) :: [{String.t(), atom()}]
    defp domain_modes(graph) do
      graph
      |> Graph.vertices({:==, :vertex_type, Domain})
      |> Enum.map(fn %Domain{domain: domain} ->
        {inspect(domain), Ash.Domain.Info.authorize(domain)}
      end)
      |> Enum.sort()
    end

    @spec domain_name(Ash.Resource.t()) :: String.t()
    defp domain_name(resource) do
      case Info.domain(resource) do
        nil -> "—"
        domain -> inspect(domain)
      end
    end

    @spec exposed?(Ash.Resource.t(), Ash.Resource.Attribute.t()) :: boolean()
    defp exposed?(resource, attribute) do
      attribute.public? and
        PolicyInfo.field_policies_for_field(resource, attribute.name) in [nil, []]
    end

    @spec pluralize(non_neg_integer(), String.t(), String.t()) :: String.t()
    defp pluralize(1, singular, _plural), do: singular
    defp pluralize(_count, _singular, plural), do: plural
  end
end
