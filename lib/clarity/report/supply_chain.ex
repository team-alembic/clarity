defmodule Clarity.Report.SupplyChain do
  @moduledoc """
  Supply-chain security report: what to do about the dependencies flagged by
  `Clarity.Status.SupplyChain`, most urgent first: known security advisories,
  then retired versions, then versions behind their latest release, each with
  the `mix deps.update` that fixes it.
  """

  @behaviour Clarity.Report

  use Clarity.Web, :live_component

  alias Clarity.Advisory
  alias Clarity.Advisory.Source
  alias Clarity.Dependency.Registry
  alias Clarity.Graph
  alias Clarity.Report.Charts
  alias Clarity.Report.Components
  alias Clarity.Status
  alias Clarity.Vertex

  # Vulnerabilities, and outdated or retired versions.
  @status_classes [:security, :hygiene]

  @typep finding() :: %{
           app: String.t(),
           id: String.t(),
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
  def category, do: "Security"

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    apps = Graph.vertices(assigns.graph, {:==, :vertex_type, Vertex.Application})
    findings = findings(assigns.graph, apps)
    flagged = MapSet.new(findings, & &1.app)

    # Only Hex packages can be checked. The project's own applications, path and
    # git dependencies, and Erlang/OTP applications have no registry entry.
    unchecked =
      apps
      |> Enum.filter(&(to_string(&1.app) not in flagged and Registry.summary(&1.app) == nil))
      |> Enum.sort_by(& &1.app)

    advised = Enum.filter(findings, & &1.advisory?)
    retired = Enum.filter(findings, &(&1.retired? and not &1.advisory?))
    outdated = Enum.filter(findings, &(&1.outdated? and not &1.retired? and not &1.advisory?))

    {:ok,
     assign(socket,
       prefix: assigns.prefix,
       lens: assigns.lens,
       advised: advised,
       retired: retired,
       outdated: outdated,
       todos: Enum.count([advised, retired, outdated], &(&1 != [])),
       unchecked: unchecked,
       pending?: not (Source.ready?() and Registry.ready?()) and findings == [],
       refreshed_at: Source.last_refreshed_at(),
       total: length(apps)
     )}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <section class="space-y-6">
      <Components.status
        count={@todos}
        pending={
          if(@pending?, do: "Still checking dependencies against the advisory database and Hex…")
        }
      >
        <:meta>{freshness(@refreshed_at)}{unchecked_note(@unchecked)}</:meta>
      </Components.status>

      <div class="grid grid-cols-2 gap-2 sm:grid-cols-4">
        <Charts.stat label="Dependencies" value={@total} />
        <Charts.stat label="Vulnerable" value={length(@advised)} tone={tone(@advised, :error)} />
        <Charts.stat label="Retired" value={length(@retired)} tone={tone(@retired, :warning)} />
        <Charts.stat label="Outdated" value={length(@outdated)} tone={tone(@outdated, :info)} />
      </div>

      <Components.todo_list :if={@todos > 0}>
        <Components.todo
          :if={@advised != []}
          severity={:high}
          title="Known vulnerabilities"
          count={length(@advised)}
          hint="A published security advisory affects the installed version."
          command={update_command(@advised)}
        >
          <div :for={finding <- @advised} class="report-todo-line">
            <.dependency finding={finding} prefix={@prefix} lens={@lens} />
            <span :for={advisory <- finding.advisories} class="basis-full pl-1 text-sm">
              <Components.chip>{advisory.id}</Components.chip>
              {advisory.summary}
              <span class="report-muted">
                · {fixed_in(advisory, finding.version)}
              </span>
            </span>
          </div>
          <:fix>Update each to a version with the fix.</:fix>
        </Components.todo>

        <Components.todo
          :if={@retired != []}
          severity={:medium}
          title="Retired versions"
          count={length(@retired)}
          hint="Their maintainers have pulled these versions from Hex."
          command={update_command(@retired)}
        >
          <div :for={finding <- @retired} class="report-todo-line">
            <.dependency finding={finding} prefix={@prefix} lens={@lens} />
          </div>
          <:fix>Move off them: update to the latest release.</:fix>
        </Components.todo>

        <Components.todo
          :if={@outdated != []}
          severity={:low}
          title="Behind their latest release"
          count={length(@outdated)}
          command={update_command(@outdated)}
        >
          <div :for={finding <- @outdated} class="report-todo-line">
            <.dependency finding={finding} prefix={@prefix} lens={@lens} />
          </div>
          <:fix>Update when convenient; a dependency pulled in by another may wait for it.</:fix>
        </Components.todo>
      </Components.todo_list>

      <Components.section
        :if={@unchecked != []}
        id="not-checked"
        title="Not checked"
        count={length(@unchecked)}
      >
        <p class="report-muted mb-3 text-sm">
          Not published on Hex: your own applications, path and git dependencies, and Erlang/OTP
          applications.
        </p>
        <div class="flex flex-wrap gap-1.5">
          <Components.chip
            :for={app <- @unchecked}
            patch={Components.path(@prefix, @lens, Vertex.id(app))}
          >
            {app.app}
          </Components.chip>
        </div>
      </Components.section>
    </section>
    """
  end

  attr :finding, :map, required: true
  attr :prefix, :string, required: true
  attr :lens, :any, required: true

  # A dependency, its version, the latest, and what pulls it in.
  @spec dependency(map()) :: Phoenix.LiveView.Rendered.t()
  defp dependency(assigns) do
    ~H"""
    <Components.chip patch={Components.path(@prefix, @lens, @finding.id)}>
      {@finding.app}
    </Components.chip>
    <span class="font-mono text-[0.8125rem] tabular-nums">
      {@finding.version}<span :if={@finding.latest && @finding.latest != @finding.version}> → {@finding.latest}</span>
    </span>
    <span :if={@finding.via != []} class="report-muted text-sm">via {via_label(@finding.via)}</span>
    """
  end

  @spec tone([finding()], atom()) :: atom()
  defp tone([], _tone), do: :neutral
  defp tone(_findings, tone), do: tone

  @spec update_command([finding()]) :: String.t()
  defp update_command(findings), do: "mix deps.update " <> Enum.map_join(findings, " ", & &1.app)

  @spec fixed_in(Advisory.t(), String.t()) :: String.t()
  defp fixed_in(advisory, version) do
    case Advisory.fixed_version(advisory, version) do
      nil -> "no fixed version yet"
      fixed -> "fixed in " <> fixed
    end
  end

  @spec freshness(DateTime.t() | nil) :: String.t()
  defp freshness(nil), do: "Advisory database not downloaded yet, so advisories may be missing."

  defp freshness(at),
    do: "Advisories as of " <> Calendar.strftime(at, "%-d %B %Y, %H:%M UTC") <> "."

  @spec unchecked_note([Vertex.Application.t()]) :: String.t()
  defp unchecked_note([]), do: ""
  defp unchecked_note(unchecked), do: " #{length(unchecked)} not on Hex, so not checked."

  @spec via_label([String.t()]) :: String.t()
  defp via_label(via), do: Enum.join(via, ", ")

  @spec findings(Graph.t(), [Vertex.Application.t()]) :: [finding()]
  defp findings(graph, apps) do
    roots = apps |> Enum.filter(&(dependents(graph, &1) == [])) |> MapSet.new(& &1.app)

    apps
    |> Enum.map(fn vertex ->
      {vertex,
       Enum.filter(Status.SupplyChain.statuses(vertex, graph), &(&1.class in @status_classes))}
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
      id: Vertex.id(vertex),
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
end
