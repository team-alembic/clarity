defmodule Clarity.Report.SupplyChain do
  @moduledoc """
  Supply-chain security report: the project's dependencies, each with its
  version, the latest release, what pulls it in, and its standing, from
  `Clarity.Status.SupplyChain`.

  Its actions (`actions/2`) are the dependencies to update, most urgent
  first: known security advisories, then retired versions, then versions
  behind their latest release, each with the `mix deps.update` that fixes
  them.
  """

  @behaviour Clarity.Report

  use Clarity.Web, :live_component

  alias Clarity.Advisory
  alias Clarity.Advisory.Source
  alias Clarity.Dependency.Registry
  alias Clarity.Graph
  alias Clarity.Report.Action
  alias Clarity.Report.Charts
  alias Clarity.Report.Components
  alias Clarity.Status
  alias Clarity.Vertex

  # Vulnerabilities, and outdated or retired versions.
  @status_classes [:security, :hygiene]

  @typep standing() :: :vulnerable | :retired | :outdated | :current | :unchecked

  @typep dependency() :: %{
           app: String.t(),
           id: String.t(),
           version: String.t(),
           latest: String.t() | nil,
           via: [String.t()],
           advisories: [Advisory.t()],
           standing: standing()
         }

  @impl Clarity.Report
  def name, do: "Supply chain security"

  @impl Clarity.Report
  def description, do: "Dependencies with advisories or outdated/retired versions"

  @impl Clarity.Report
  def category, do: "Security"

  @impl Clarity.Report
  def actions(graph, _opts) do
    by_standing = graph |> dependencies() |> Enum.group_by(& &1.standing)

    Enum.reject(
      [
        action(
          :high,
          "Known vulnerabilities",
          "A published security advisory affects the installed version.",
          "Update each to a version with the fix.",
          by_standing[:vulnerable]
        ),
        action(
          :medium,
          "Retired versions",
          "Their maintainers have pulled these versions from Hex.",
          "Move off them: update to the latest release.",
          by_standing[:retired]
        ),
        action(
          :low,
          "Behind their latest release",
          nil,
          "Update when convenient; a dependency pulled in by another may wait for it.",
          by_standing[:outdated]
        )
      ],
      &is_nil/1
    )
  end

  @impl Clarity.Report
  def pending(graph) do
    if not (Source.ready?() and Registry.ready?()) and actions(graph, []) == [],
      do: "Still checking dependencies against the advisory database and Hex…"
  end

  @spec action(Action.severity(), String.t(), String.t() | nil, String.t(), [dependency()] | nil) ::
          Action.t() | nil
  defp action(_severity, _title, _hint, _fix, nil), do: nil

  defp action(severity, title, hint, fix, dependencies) do
    %Action{
      severity: severity,
      title: title,
      hint: hint,
      fix: fix,
      command: "mix deps.update " <> Enum.map_join(dependencies, " ", & &1.app),
      layout: :lines,
      groups: [%{items: Enum.map(dependencies, &item/1)}]
    }
  end

  @spec item(dependency()) :: Action.item()
  defp item(dependency) do
    %{
      text: dependency.app,
      id: dependency.id,
      note: Enum.join([versions(dependency) | via_note(dependency.via)], " "),
      details: Enum.map(dependency.advisories, &advisory_line(&1, dependency.version))
    }
  end

  @spec versions(dependency()) :: String.t()
  defp versions(%{latest: latest, version: version}) when latest in [nil, version], do: version
  defp versions(%{latest: latest, version: version}), do: "#{version} → #{latest}"

  @spec via_note([String.t()]) :: [String.t()]
  defp via_note([]), do: []
  defp via_note(via), do: ["via " <> Enum.join(via, ", ")]

  @spec advisory_line(Advisory.t(), String.t()) :: String.t()
  defp advisory_line(advisory, version) do
    [advisory.id, advisory.summary, fixed_in(advisory, version)]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(" · ")
  end

  @spec fixed_in(Advisory.t(), String.t()) :: String.t()
  defp fixed_in(advisory, version) do
    case Advisory.fixed_version(advisory, version) do
      nil -> "no fixed version yet"
      fixed -> "fixed in " <> fixed
    end
  end

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    dependencies = dependencies(assigns.graph)
    by_standing = Enum.frequencies_by(dependencies, & &1.standing)

    {:ok,
     assign(socket,
       prefix: assigns.prefix,
       lens: assigns.lens,
       dependencies: Enum.sort_by(dependencies, &{standing_index(&1.standing), &1.app}),
       counts: by_standing,
       refreshed_at: Source.last_refreshed_at()
     )}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <section class="space-y-6">
      <div class="space-y-2">
        <div class="grid grid-cols-2 gap-2 sm:grid-cols-4">
          <Charts.stat label="Dependencies" value={length(@dependencies)} />
          <Charts.stat
            label="Vulnerable"
            value={@counts[:vulnerable] || 0}
            tone={tone(@counts[:vulnerable], :error)}
          />
          <Charts.stat
            label="Retired"
            value={@counts[:retired] || 0}
            tone={tone(@counts[:retired], :warning)}
          />
          <Charts.stat
            label="Outdated"
            value={@counts[:outdated] || 0}
            tone={tone(@counts[:outdated], :info)}
          />
        </div>
        <p class="report-status-meta">
          {freshness(@refreshed_at)}
          <span :if={@counts[:unchecked]}>{@counts[:unchecked]} not on Hex, so not checked.</span>
        </p>
      </div>

      <Components.section id="dependencies" title="Dependencies" count={length(@dependencies)}>
        <table class="report-table">
          <thead>
            <tr>
              <th>Dependency</th>
              <th>Installed</th>
              <th>Latest</th>
              <th>Pulled in by</th>
              <th>Standing</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={dependency <- @dependencies}>
              <td>
                <.link patch={Components.path(@prefix, @lens, dependency.id)} class="report-link">
                  {dependency.app}
                </.link>
              </td>
              <td class="font-mono text-[0.8125rem] tabular-nums">{dependency.version}</td>
              <td class="font-mono text-[0.8125rem] tabular-nums">
                <span :if={dependency.latest}>{dependency.latest}</span>
                <span :if={!dependency.latest} class="report-muted">—</span>
              </td>
              <td>
                <span :if={dependency.via == []} class="report-muted">your project</span>
                <span :if={dependency.via != []}>{Enum.join(dependency.via, ", ")}</span>
              </td>
              <td><.standing standing={dependency.standing} /></td>
            </tr>
          </tbody>
        </table>
      </Components.section>
    </section>
    """
  end

  attr :standing, :atom, required: true

  @spec standing(map()) :: Phoenix.LiveView.Rendered.t()
  defp standing(%{standing: :vulnerable} = assigns),
    do: ~H|<span class="report-tag" data-tone="error">vulnerable</span>|

  defp standing(%{standing: :retired} = assigns),
    do: ~H|<span class="report-tag" data-tone="warning">retired</span>|

  defp standing(%{standing: :outdated} = assigns),
    do: ~H|<span class="report-tag" data-tone="info">outdated</span>|

  defp standing(%{standing: :current} = assigns),
    do: ~H|<span class="report-tag" data-tone="ok">current</span>|

  defp standing(%{standing: :unchecked} = assigns), do: ~H|<span
  class="report-tag"
  {Clarity.Tooltip.attrs("Not on Hex: your own applications, path and git dependencies, and Erlang/OTP applications.")}
>not checked</span>|

  @spec standing_index(standing()) :: non_neg_integer()
  defp standing_index(standing),
    do:
      Enum.find_index([:vulnerable, :retired, :outdated, :current, :unchecked], &(&1 == standing))

  @spec tone(non_neg_integer() | nil, atom()) :: atom()
  defp tone(nil, _tone), do: :neutral
  defp tone(_count, tone), do: tone

  @spec freshness(DateTime.t() | nil) :: String.t()
  defp freshness(nil), do: "Advisory database not downloaded yet, so advisories may be missing."

  defp freshness(at),
    do: "Advisories as of " <> Calendar.strftime(at, "%-d %B %Y, %H:%M UTC") <> "."

  # Every dependency, with where it stands.
  @spec dependencies(Graph.t()) :: [dependency()]
  defp dependencies(graph) do
    apps = Graph.vertices(graph, {:==, :vertex_type, Vertex.Application})
    roots = apps |> Enum.filter(&(dependents(graph, &1) == [])) |> MapSet.new(& &1.app)

    apps
    |> Enum.map(&dependency(&1, graph, roots))
    |> Enum.sort_by(& &1.app)
  end

  @spec dependency(Vertex.Application.t(), Graph.t(), MapSet.t(atom())) :: dependency()
  defp dependency(vertex, graph, roots) do
    version = to_string(vertex.version)

    statuses =
      Enum.filter(Status.SupplyChain.statuses(vertex, graph), &(&1.class in @status_classes))

    %{
      app: to_string(vertex.app),
      id: Vertex.id(vertex),
      version: version,
      latest: latest(vertex.app),
      via: via(graph, vertex, roots),
      advisories: Source.advisories_for(vertex.app, version),
      standing: standing_of(statuses, Registry.summary(vertex.app))
    }
  end

  # Only Hex packages can be checked: the project's own applications, path and
  # git dependencies, and Erlang/OTP applications have no registry entry.
  @spec standing_of([Status.t()], map() | nil) :: standing()
  defp standing_of(statuses, summary) do
    cond do
      Enum.any?(statuses, &(&1.class == :security)) -> :vulnerable
      Enum.any?(statuses, &(&1.class == :hygiene and &1.severity == :warning)) -> :retired
      Enum.any?(statuses, &(&1.class == :hygiene and &1.severity == :info)) -> :outdated
      summary == nil -> :unchecked
      true -> :current
    end
  end

  # Applications that directly depend on `vertex` (the `:dependency` edges point
  # dependent → dependency, so dependents are the in-neighbours).
  @spec dependents(Graph.t(), Vertex.Application.t()) :: [Vertex.Application.t()]
  defp dependents(graph, vertex) do
    graph |> Graph.in_neighbors(vertex) |> Enum.filter(&match?(%Vertex.Application{}, &1))
  end

  # Which of the project's dependencies pull `vertex` in. If a root project app
  # depends on it directly, it's a direct dependency (an empty list);
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
end
