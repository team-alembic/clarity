with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Report.SecurityPosture do
    @moduledoc """
    Security posture report: a written review of how each Ash resource under the
    security lens is protected — policy enforcement, bypass policies, and
    sensitive-field exposure.

    The report is prose: it explains, in sentences, which resources carry a
    concern and why it matters, rather than presenting a table to operate.
    """

    @behaviour Clarity.Report

    use Clarity.Web, :live_component

    import Clarity.Components.MarkdownComponent

    alias Ash.Policy.Info, as: PolicyInfo
    alias Ash.Resource.Info
    alias Clarity.Graph
    alias Clarity.Perspective.Lens
    alias Clarity.Report.Charts
    alias Clarity.Vertex
    alias Clarity.Vertex.Ash.Resource

    @authorizer Ash.Policy.Authorizer

    @typep finding() :: %{
             name: String.t(),
             governed?: boolean(),
             bypass?: boolean(),
             exposed: [String.t()],
             sensitive: non_neg_integer()
           }

    @impl Clarity.Report
    def name, do: "Security posture"

    @impl Clarity.Report
    def description, do: "Policy enforcement and sensitive-field exposure across resources"

    @impl Clarity.Report
    def applies?(%Lens{id: "security"}), do: true
    def applies?(_lens), do: false

    @impl Phoenix.LiveComponent
    def update(assigns, socket) do
      findings = findings(assigns.graph)

      domains =
        assigns.graph |> Graph.vertices({:==, :vertex_type, Vertex.Ash.Domain}) |> length()

      {:ok,
       assign(socket,
         prefix: assigns.prefix,
         lens: assigns.lens,
         markdown: build_markdown(findings, domains),
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
          <Charts.pie title="Policy coverage" segments={@dashboard.segments} />
        </div>

        <.markdown content={@markdown} prefix={@prefix} lens={@lens} class="max-w-[75ch]" />
      </section>
      """
    end

    @spec dashboard([finding()]) :: map()
    defp dashboard(findings) do
      total = length(findings)
      governed = Enum.count(findings, & &1.governed?)

      %{
        resources: total,
        open: total - governed,
        bypass: Enum.count(findings, & &1.bypass?),
        exposed: Enum.count(findings, &(&1.exposed != [])),
        segments: [
          %{label: "Governed", value: governed, tone: :ok},
          %{label: "Open", value: total - governed, tone: :warning}
        ]
      }
    end

    @spec build_markdown([finding()], non_neg_integer()) :: iodata()
    defp build_markdown(findings, domains) do
      [
        "This report reviews how each Ash resource is protected. It surfaces facts that ",
        "aren't obvious from any single file: whether a resource is governed by policies, ",
        "whether a bypass can skip them, and whether sensitive fields are exposed. These are ",
        "*findings, not verdicts* — Ash has legitimate reasons for each pattern, so you decide ",
        "what warrants attention.\n\n",
        overview(findings, domains),
        enforcement_section(findings),
        bypass_section(findings),
        exposure_section(findings)
      ]
    end

    @spec overview([finding()], non_neg_integer()) :: iodata()
    defp overview([], _domains) do
      "No Ash resources are visible under this lens, so there is no authorisation posture to report.\n\n"
    end

    defp overview(findings, domains) do
      total = length(findings)
      governed = Enum.count(findings, & &1.governed?)

      [
        "Clarity can see ",
        Integer.to_string(total),
        pluralize(total, " resource", " resources"),
        if(domains > 0,
          do: [" across ", Integer.to_string(domains), pluralize(domains, " domain", " domains")],
          else: []
        ),
        ". ",
        Integer.to_string(governed),
        " of them ",
        pluralize(governed, "enforces", "enforce"),
        " policies; the rest are open. ",
        Integer.to_string(Enum.count(findings, & &1.bypass?)),
        " carry a bypass, and ",
        Integer.to_string(Enum.count(findings, &(&1.exposed != []))),
        " expose sensitive fields.\n\n"
      ]
    end

    @spec enforcement_section([finding()]) :: iodata()
    defp enforcement_section([]), do: []

    defp enforcement_section(findings) do
      open = Enum.filter(findings, &(not &1.governed?))

      [
        "### Policy enforcement\n\n",
        case open do
          [] ->
            "Every resource is governed by a policy authorizer, so Ash policies apply to each.\n\n"

          _present ->
            [
              names(open),
              " ",
              pluralize(length(open), "has", "have"),
              " no policy authorizer. Ash policies therefore place no restriction on ",
              pluralize(length(open), "it", "them"),
              " — every action is allowed, subject to the domain's authorisation mode. If ",
              pluralize(length(open), "it exposes", "they expose"),
              " or mutate anything sensitive, add policies.\n\n"
            ]
        end
      ]
    end

    @spec bypass_section([finding()]) :: iodata()
    defp bypass_section([]), do: []

    defp bypass_section(findings) do
      bypass = Enum.filter(findings, & &1.bypass?)

      [
        "### Bypass policies\n\n",
        case bypass do
          [] ->
            "No resource uses a bypass policy.\n\n"

          _present ->
            [
              names(bypass),
              " ",
              pluralize(length(bypass), "carries", "carry"),
              " a bypass policy. A passing bypass short-circuits every other policy for the ",
              "request — usually an admin escape hatch — so confirm the bypass condition is as ",
              "tight as you intend.\n\n"
            ]
        end
      ]
    end

    @spec exposure_section([finding()]) :: iodata()
    defp exposure_section([]), do: []

    defp exposure_section(findings) do
      exposed = Enum.filter(findings, &(&1.exposed != []))

      [
        "### Sensitive field exposure\n\n",
        case exposed do
          [] ->
            "No sensitive attribute is publicly exposed without a field policy.\n\n"

          _present ->
            [
              "A sensitive attribute that is also public, with no field policy covering it, is ",
              "visible wherever the resource is rendered — APIs, serialised responses, admin UIs.\n\n",
              Enum.map(exposed, &exposure_paragraph/1)
            ]
        end
      ]
    end

    @spec exposure_paragraph(finding()) :: iodata()
    defp exposure_paragraph(finding) do
      [
        "**",
        finding.name,
        "** exposes ",
        Enum.map_join(finding.exposed, ", ", &"`#{&1}`"),
        ".\n\n"
      ]
    end

    @spec names([finding()]) :: iodata()
    defp names(findings) do
      findings
      |> Enum.map(&"**#{&1.name}**")
      |> to_sentence()
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
      sensitive = Enum.filter(Info.attributes(resource), & &1.sensitive?)

      %{
        name: Vertex.name(vertex),
        governed?: @authorizer in Info.authorizers(resource),
        bypass?: Enum.any?(PolicyInfo.policies(resource), & &1.bypass?),
        exposed:
          sensitive |> Enum.filter(&exposed?(resource, &1)) |> Enum.map(&to_string(&1.name)),
        sensitive: length(sensitive)
      }
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
