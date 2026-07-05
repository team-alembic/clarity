defmodule Clarity.Report.SupplyChain do
  @moduledoc """
  Supply-chain security report: a written review of the dependencies flagged by
  `Clarity.Status.SupplyChain` — known security advisories, and outdated or
  retired versions — under the security lens.

  The report is prose: it explains, in sentences, which dependencies carry a
  concern and why it matters, rather than presenting a table to operate.
  """

  @behaviour Clarity.Report

  use Clarity.Web, :live_component

  import Clarity.Components.MarkdownComponent

  alias Clarity.Advisory
  alias Clarity.Advisory.Source
  alias Clarity.Dependency.Registry
  alias Clarity.Graph
  alias Clarity.Perspective.Lens
  alias Clarity.Report.Charts
  alias Clarity.Status
  alias Clarity.Vertex

  @typep finding() :: %{
           app: String.t(),
           version: String.t(),
           latest: String.t() | nil,
           via: [String.t()],
           advisories: [Advisory.t()],
           advisory?: boolean(),
           outdated?: boolean(),
           retired?: boolean()
         }

  @impl Clarity.Report
  def name, do: "Supply chain security"

  @impl Clarity.Report
  def description, do: "Dependencies with advisories or outdated/retired versions"

  @impl Clarity.Report
  def applies?(%Lens{id: "security"}), do: true
  def applies?(_lens), do: false

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    findings = findings(assigns.graph, assigns.lens)
    total = assigns.graph |> Graph.vertices({:==, :vertex_type, Vertex.Application}) |> length()

    {:ok,
     assign(socket,
       prefix: assigns.prefix,
       lens: assigns.lens,
       markdown: build_markdown(findings),
       dashboard: dashboard(findings, total)
     )}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <section class="space-y-6">
      <div class="space-y-4">
        <h2 class="text-2xl font-bold">Supply chain security</h2>
        <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
          <Charts.stat label="Dependencies" value={@dashboard.total} />
          <Charts.stat label="Advisories" value={@dashboard.advisories} tone={:error} />
          <Charts.stat label="Outdated" value={@dashboard.outdated} tone={:info} />
          <Charts.stat label="Retired" value={@dashboard.retired} tone={:warning} />
        </div>
        <Charts.pie title="Dependency health" segments={@dashboard.segments} />
      </div>

      <.markdown content={@markdown} prefix={@prefix} lens={@lens} class="max-w-[75ch]" />
    </section>
    """
  end

  @spec dashboard([finding()], non_neg_integer()) :: map()
  defp dashboard(findings, total) do
    advisory = Enum.count(findings, & &1.advisory?)
    retired_only = Enum.count(findings, &(&1.retired? and not &1.advisory?))
    outdated_only = Enum.count(findings, &(&1.outdated? and not &1.advisory? and not &1.retired?))
    healthy = max(total - length(findings), 0)

    %{
      total: total,
      advisories: advisory,
      outdated: Enum.count(findings, & &1.outdated?),
      retired: Enum.count(findings, & &1.retired?),
      segments: [
        %{label: "Healthy", value: healthy, tone: :ok},
        %{label: "Advisory", value: advisory, tone: :error},
        %{label: "Retired", value: retired_only, tone: :warning},
        %{label: "Outdated", value: outdated_only, tone: :info}
      ]
    }
  end

  @spec build_markdown([finding()]) :: iodata()
  defp build_markdown(findings) do
    [
      "This report reviews the dependencies your project runs for supply-chain risk: ",
      "known security advisories, versions that have fallen behind their latest release, ",
      "and versions their maintainers have retired. Each item is a *finding* — a fact and ",
      "why it might matter — not a verdict that you are exploitable.\n\n",
      freshness(),
      overview(findings),
      advisories_section(findings),
      hygiene_section(findings)
    ]
  end

  @spec freshness() :: iodata()
  defp freshness do
    case Source.last_refreshed_at() do
      nil ->
        "The advisory database has not been downloaded yet, so advisory findings may be incomplete.\n\n"

      at ->
        [
          "Advisories are matched against a database last refreshed on ",
          Calendar.strftime(at, "%-d %B %Y at %H:%M UTC"),
          "; findings are only as current as that refresh.\n\n"
        ]
    end
  end

  @spec overview([finding()]) :: iodata()
  defp overview([]) do
    "**Nothing is flagged.** Every dependency Clarity can see is on a current, " <>
      "non-retired version with no known security advisory.\n\n"
  end

  defp overview(findings) do
    total = length(findings)
    advisories = Enum.count(findings, & &1.advisory?)
    outdated = Enum.count(findings, & &1.outdated?)
    retired = Enum.count(findings, & &1.retired?)

    [
      "Of the dependencies Clarity can see, **",
      Integer.to_string(total),
      pluralize(total, " dependency carries", " dependencies carry"),
      " a supply-chain concern**: ",
      Enum.join(
        Enum.reject(
          [
            phrase(advisories, "a security advisory", "security advisories"),
            phrase(outdated, "an outdated version", "outdated versions"),
            phrase(retired, "a retired version", "retired versions")
          ],
          &(&1 == nil)
        ),
        ", "
      ),
      ".\n\n"
    ]
  end

  @spec advisories_section([finding()]) :: iodata()
  defp advisories_section(findings) do
    advised = Enum.filter(findings, & &1.advisory?)

    [
      "### Security advisories\n\n",
      case advised do
        [] ->
          "No dependency has a known security advisory.\n\n"

        _present ->
          [
            "A published advisory means a known vulnerability affects the installed version; ",
            "where a maintainer has shipped a fix, updating resolves it.\n\n",
            Enum.map(advised, &advisory_paragraph/1)
          ]
      end
    ]
  end

  @spec advisory_paragraph(finding()) :: iodata()
  defp advisory_paragraph(finding) do
    ids = Enum.map_join(finding.advisories, ", ", & &1.id)
    fixed = fixed_versions(finding)

    [
      "**",
      finding.app,
      " ",
      finding.version,
      "** is affected by ",
      Integer.to_string(length(finding.advisories)),
      " ",
      pluralize(length(finding.advisories), "advisory", "advisories"),
      " (",
      ids,
      "). ",
      case fixed do
        [] -> "No fixed version is published yet. "
        versions -> ["A fix is available — update to #{Enum.join(versions, " or ")}. "]
      end,
      summaries(finding.advisories),
      "\n\n"
    ]
  end

  @spec hygiene_section([finding()]) :: iodata()
  defp hygiene_section(findings) do
    hygiene = Enum.filter(findings, &(&1.retired? or &1.outdated?))

    [
      "### Dependency hygiene\n\n",
      case hygiene do
        [] ->
          "Every dependency is on a current, non-retired version.\n\n"

        rows ->
          [
            "Retired versions have been pulled from Hex and should be moved off; ",
            "outdated ones are simply behind their latest release. *Via* names the ",
            "direct dependency that pulls a transitive one in.\n\n",
            "| Dependency | Via | Installed | Latest | Status |\n",
            "| --- | --- | --- | --- | --- |\n",
            Enum.map(rows, &hygiene_row/1),
            "\n"
          ]
      end
    ]
  end

  @spec hygiene_row(finding()) :: iodata()
  defp hygiene_row(finding) do
    status = if finding.retired?, do: "Retired", else: "Outdated"

    [
      "| **",
      finding.app,
      "** | ",
      via_label(finding.via),
      " | ",
      finding.version,
      " | ",
      finding.latest || "—",
      " | ",
      status,
      " |\n"
    ]
  end

  @spec via_label([String.t()]) :: String.t()
  defp via_label([]), do: "direct"
  defp via_label(via), do: Enum.join(via, ", ")

  @spec summaries([Advisory.t()]) :: iodata()
  defp summaries(advisories) do
    advisories
    |> Enum.map(& &1.summary)
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.map_join(" ", &String.trim/1)
  end

  @spec fixed_versions(finding()) :: [String.t()]
  defp fixed_versions(finding) do
    finding.advisories
    |> Enum.map(&Advisory.fixed_version(&1, finding.version))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  @spec findings(Graph.t(), Lens.t()) :: [finding()]
  defp findings(graph, lens) do
    apps = Graph.vertices(graph, {:==, :vertex_type, Vertex.Application})
    roots = apps |> Enum.filter(&(dependents(graph, &1) == [])) |> MapSet.new(& &1.app)

    apps
    |> Enum.map(fn vertex ->
      {vertex, Enum.filter(Status.SupplyChain.statuses(vertex, graph), lens.status_filter)}
    end)
    |> Enum.reject(fn {_vertex, statuses} -> statuses == [] end)
    |> Enum.map(fn {vertex, statuses} -> finding(vertex, statuses, via(graph, vertex, roots)) end)
    |> Enum.sort_by(& &1.app)
  end

  @spec finding(Vertex.Application.t(), [Status.t()], [String.t()]) :: finding()
  defp finding(vertex, statuses, via) do
    version = to_string(vertex.version)

    %{
      app: to_string(vertex.app),
      version: version,
      latest: latest(vertex.app),
      via: via,
      advisories: Source.advisories_for(vertex.app, version),
      advisory?: Enum.any?(statuses, &(&1.class == :security)),
      outdated?: Enum.any?(statuses, &(&1.class == :hygiene and &1.severity == :info)),
      retired?: Enum.any?(statuses, &(&1.class == :hygiene and &1.severity == :warning))
    }
  end

  # Applications that directly depend on `vertex` (the `:dependency` edges point
  # dependent → dependency, so dependents are the in-neighbours).
  @spec dependents(Graph.t(), Vertex.Application.t()) :: [Vertex.Application.t()]
  defp dependents(graph, vertex) do
    graph |> Graph.in_neighbors(vertex) |> Enum.filter(&match?(%Vertex.Application{}, &1))
  end

  # Which of the project's dependencies pull `vertex` in. If a root project app
  # depends on it directly, it's a direct dependency (empty list → "direct");
  # otherwise it's the transitive dependents that require it.
  @spec via(Graph.t(), Vertex.Application.t(), MapSet.t(atom())) :: [String.t()]
  defp via(graph, vertex, roots) do
    deps = graph |> dependents(vertex) |> Enum.map(& &1.app)

    if Enum.any?(deps, &MapSet.member?(roots, &1)) do
      []
    else
      deps |> Enum.uniq() |> Enum.sort() |> Enum.map(&to_string/1)
    end
  end

  @spec latest(atom()) :: String.t() | nil
  defp latest(app) do
    case Registry.summary(app) do
      %{latest: latest} -> latest
      nil -> nil
    end
  end

  @spec phrase(non_neg_integer(), String.t(), String.t()) :: String.t() | nil
  defp phrase(0, _singular, _plural), do: nil
  defp phrase(1, singular, _plural), do: "1 with #{singular}"
  defp phrase(count, _singular, plural), do: "#{count} with #{plural}"

  @spec pluralize(non_neg_integer(), String.t(), String.t()) :: String.t()
  defp pluralize(1, singular, _plural), do: singular
  defp pluralize(_count, _singular, plural), do: plural
end
