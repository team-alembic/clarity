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
  alias Clarity.Status
  alias Clarity.Vertex

  @typep finding() :: %{
           app: String.t(),
           version: String.t(),
           latest: String.t() | nil,
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
    {:ok,
     assign(socket,
       prefix: assigns.prefix,
       lens: assigns.lens,
       markdown: markdown(assigns.graph, assigns.lens)
     )}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <section>
      <.markdown content={@markdown} prefix={@prefix} lens={@lens} class="max-w-[75ch]" />
    </section>
    """
  end

  @spec markdown(Graph.t(), Lens.t()) :: iodata()
  defp markdown(graph, lens) do
    findings = findings(graph, lens)

    [
      "## Supply chain security\n\n",
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
    retired = Enum.filter(findings, & &1.retired?)
    outdated = Enum.filter(findings, &(&1.outdated? and not &1.retired?))

    [
      "### Dependency hygiene\n\n",
      retired_prose(retired),
      outdated_prose(outdated),
      if(retired == [] and outdated == [],
        do: "Every dependency is on a current, non-retired version.\n\n",
        else: []
      )
    ]
  end

  @spec retired_prose([finding()]) :: iodata()
  defp retired_prose([]), do: []

  defp retired_prose(retired) do
    [
      "The maintainers of ",
      Enum.map_join(retired, ", ", &"**#{&1.app} #{&1.version}**"),
      " have retired the installed version from Hex — usually a sign of a security ",
      "problem or serious bug — so you should move off ",
      pluralize(length(retired), "it", "them"),
      ".\n\n"
    ]
  end

  @spec outdated_prose([finding()]) :: iodata()
  defp outdated_prose([]), do: []

  defp outdated_prose(outdated) do
    [
      if(length(outdated) == 1,
        do: "One dependency is",
        else: "#{length(outdated)} dependencies are"
      ),
      " behind the latest published release: ",
      Enum.map_join(outdated, ", ", &"**#{&1.app}** (#{&1.version} → #{&1.latest || "?"})"),
      ". Staying current is the simplest way to pick up upstream fixes.\n\n"
    ]
  end

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
    graph
    |> Graph.vertices({:==, :vertex_type, Vertex.Application})
    |> Enum.map(fn vertex ->
      {vertex, Enum.filter(Status.SupplyChain.statuses(vertex, graph), lens.status_filter)}
    end)
    |> Enum.reject(fn {_vertex, statuses} -> statuses == [] end)
    |> Enum.map(&finding/1)
    |> Enum.sort_by(& &1.app)
  end

  @spec finding({Vertex.Application.t(), [Status.t()]}) :: finding()
  defp finding({vertex, statuses}) do
    version = to_string(vertex.version)

    %{
      app: to_string(vertex.app),
      version: version,
      latest: latest(vertex.app),
      advisories: Source.advisories_for(vertex.app, version),
      advisory?: Enum.any?(statuses, &(&1.class == :security)),
      outdated?: Enum.any?(statuses, &(&1.class == :hygiene and &1.severity == :info)),
      retired?: Enum.any?(statuses, &(&1.class == :hygiene and &1.severity == :warning))
    }
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
