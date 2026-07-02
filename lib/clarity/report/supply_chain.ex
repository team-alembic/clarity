defmodule Clarity.Report.SupplyChain do
  @moduledoc """
  Supply-chain security report: every dependency flagged by
  `Clarity.Status.SupplyChain` — a security advisory, or an outdated/retired
  version — rolled up into one interactive view under the security lens.

  Findings can be filtered by kind (advisory / outdated / retired) and the table
  sorted by dependency or severity.
  """

  @behaviour Clarity.Report

  use Clarity.Web, :live_component

  alias Clarity.Advisory.Source
  alias Clarity.Graph
  alias Clarity.Perspective.Lens
  alias Clarity.Status
  alias Clarity.Vertex
  alias Phoenix.LiveView.Rendered

  @type row() :: %{
          vertex: Vertex.Application.t(),
          app: String.t(),
          version: String.t(),
          statuses: [Status.t()],
          severity: Status.severity()
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
    rows = build_rows(assigns.graph, assigns.lens)

    {:ok,
     socket
     |> assign(prefix: assigns.prefix, lens: assigns.lens)
     |> assign(rows: rows, totals: totals(rows), refreshed_at: Source.last_refreshed_at())
     |> assign_new(:filter, fn -> :all end)
     |> assign_new(:sort, fn -> {:severity, :desc} end)}
  end

  @impl Phoenix.LiveComponent
  def handle_event("filter", %{"kind" => kind}, socket) do
    {:noreply, assign(socket, filter: String.to_existing_atom(kind))}
  end

  def handle_event("sort", %{"field" => field}, socket) do
    field = String.to_existing_atom(field)

    sort =
      case socket.assigns.sort do
        {^field, :asc} -> {field, :desc}
        {^field, :desc} -> {field, :asc}
        _other -> {field, default_dir(field)}
      end

    {:noreply, assign(socket, sort: sort)}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    assigns =
      assign(
        assigns,
        :visible,
        assigns.rows |> filter_rows(assigns.filter) |> sort_rows(assigns.sort)
      )

    ~H"""
    <section>
      <h2 class="text-2xl font-bold mb-2">Supply chain security</h2>

      <p class="opacity-80 mb-3 leading-relaxed max-w-[70ch]">
        This report gathers every dependency that carries a supply-chain concern — a
        known security advisory, a newer published version, or a version that has been
        retired from Hex. Each row is a <em>finding</em>: a fact about a dependency and
        why it might matter, not a verdict that you are vulnerable. Filter to a category
        below, and follow a dependency's link to see its full detail in the graph.
      </p>

      <p :if={@refreshed_at} class="text-sm italic opacity-60 mb-4">
        Advisories are matched against a database last refreshed {Calendar.strftime(
          @refreshed_at,
          "%-d %B %Y at %H:%M UTC"
        )}; findings are only
        as current as that refresh.
      </p>

      <%= if @rows == [] do %>
        <p class="opacity-80 max-w-[70ch]">
          No dependency is flagged under this lens: there are no known advisories, and
          every dependency is on a current, non-retired version. This reflects the last
          advisory-database refresh noted above.
        </p>
      <% else %>
        <p class="opacity-70 mb-3">{summary(@totals)}</p>

        <dl class="text-sm space-y-1 mb-4 max-w-[70ch]">
          <div class="flex gap-2">
            <dt class="font-semibold w-20 shrink-0 text-red-700 dark:text-red-300">Advisory</dt>
            <dd class="opacity-80">
              A published security advisory affects the installed version. A fixed
              version may be available — see the dependency's Advisories tab.
            </dd>
          </div>
          <div class="flex gap-2">
            <dt class="font-semibold w-20 shrink-0 text-yellow-700 dark:text-yellow-300">Retired</dt>
            <dd class="opacity-80">
              The installed version has been retired from Hex by its maintainer (often
              for a security issue or a serious bug).
            </dd>
          </div>
          <div class="flex gap-2">
            <dt class="font-semibold w-20 shrink-0 text-blue-700 dark:text-blue-300">Outdated</dt>
            <dd class="opacity-80">
              A newer version is published on Hex; the installed version is behind.
            </dd>
          </div>
        </dl>

        <div class="flex flex-wrap gap-1 mb-4">
          <.chip myself={@myself} kind={:all} active={@filter} label="All" count={@totals.deps} />
          <.chip
            myself={@myself}
            kind={:advisory}
            active={@filter}
            label="Advisories"
            count={@totals.advisories}
          />
          <.chip
            myself={@myself}
            kind={:outdated}
            active={@filter}
            label="Outdated"
            count={@totals.outdated}
          />
          <.chip
            myself={@myself}
            kind={:retired}
            active={@filter}
            label="Retired"
            count={@totals.retired}
          />
        </div>

        <table class="w-full text-sm">
          <thead>
            <tr class="text-left border-b border-base-light-300 dark:border-base-dark-700">
              <.sort_header myself={@myself} field={:app} sort={@sort} label="Dependency" />
              <.sort_header myself={@myself} field={:severity} sort={@sort} label="Severity" />
              <th class="py-2 font-semibold">Findings</th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={row <- @visible}
              class="border-b border-base-light-200 dark:border-base-dark-800 align-top"
            >
              <td class="py-2 pr-4 font-medium">
                <.link
                  navigate={Path.join([@prefix, @lens.id, Vertex.id(row.vertex)])}
                  class="text-primary-light dark:text-primary-dark hover:underline"
                >
                  {row.app}
                </.link>
                <span class="opacity-60 tabular-nums ml-1">{row.version}</span>
              </td>
              <td class="py-2 pr-4">
                <span class={["capitalize font-medium", finding_class(row.severity)]}>
                  {row.severity}
                </span>
              </td>
              <td class="py-2">
                <ul class="space-y-1">
                  <li :for={status <- row.statuses} class={finding_class(status.severity)}>
                    {status.message}
                  </li>
                </ul>
              </td>
            </tr>
          </tbody>
        </table>
      <% end %>
    </section>
    """
  end

  attr :myself, :any, required: true
  attr :kind, :atom, required: true
  attr :active, :atom, required: true
  attr :label, :string, required: true
  attr :count, :integer, required: true

  @spec chip(map()) :: Rendered.t()
  defp chip(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="filter"
      phx-value-kind={@kind}
      phx-target={@myself}
      class={[
        "px-2.5 py-1 rounded-full text-xs font-medium ring-1 ring-inset transition-colors",
        if(@active == @kind,
          do: "bg-primary-light dark:bg-primary-dark text-white ring-transparent",
          else:
            "text-base-light-700 dark:text-base-dark-300 ring-base-light-300 dark:ring-base-dark-600 hover:bg-base-light-200 dark:hover:bg-base-dark-700"
        )
      ]}
    >
      {@label} <span class="tabular-nums opacity-80">{@count}</span>
    </button>
    """
  end

  attr :myself, :any, required: true
  attr :field, :atom, required: true
  attr :sort, :any, required: true
  attr :label, :string, required: true

  @spec sort_header(map()) :: Rendered.t()
  defp sort_header(assigns) do
    ~H"""
    <th class="py-2 pr-4 font-semibold">
      <button
        type="button"
        phx-click="sort"
        phx-value-field={@field}
        phx-target={@myself}
        class="inline-flex items-center gap-1 hover:text-primary-light dark:hover:text-primary-dark"
      >
        {@label}
        <span class="text-xs opacity-70">{sort_caret(@sort, @field)}</span>
      </button>
    </th>
    """
  end

  @spec sort_caret({atom(), :asc | :desc}, atom()) :: String.t()
  defp sort_caret({field, :asc}, field), do: "▲"
  defp sort_caret({field, :desc}, field), do: "▼"
  defp sort_caret(_sort, _field), do: ""

  @spec build_rows(Graph.t(), Lens.t()) :: [row()]
  defp build_rows(graph, lens) do
    graph
    |> Graph.vertices({:==, :vertex_type, Vertex.Application})
    |> Enum.map(fn vertex ->
      {vertex, Enum.filter(Status.SupplyChain.statuses(vertex, graph), lens.status_filter)}
    end)
    |> Enum.reject(fn {_vertex, statuses} -> statuses == [] end)
    |> Enum.map(&build_row/1)
  end

  @spec build_row({Vertex.Application.t(), [Status.t()]}) :: row()
  defp build_row({vertex, statuses}) do
    severity =
      statuses |> Enum.map(& &1.severity) |> Enum.reduce(&Status.max_severity/2)

    %{
      vertex: vertex,
      app: to_string(vertex.app),
      version: to_string(vertex.version),
      statuses: statuses,
      severity: severity
    }
  end

  @spec filter_rows([row()], atom()) :: [row()]
  defp filter_rows(rows, :all), do: rows
  defp filter_rows(rows, kind), do: Enum.filter(rows, &row_matches?(&1, kind))

  @spec row_matches?(row(), atom()) :: boolean()
  defp row_matches?(%{statuses: statuses}, :advisory),
    do: Enum.any?(statuses, &(&1.class == :security))

  defp row_matches?(%{statuses: statuses}, :outdated),
    do: Enum.any?(statuses, &(&1.class == :hygiene and &1.severity == :info))

  defp row_matches?(%{statuses: statuses}, :retired),
    do: Enum.any?(statuses, &(&1.class == :hygiene and &1.severity == :warning))

  @spec sort_rows([row()], {atom(), :asc | :desc}) :: [row()]
  defp sort_rows(rows, {:app, dir}), do: Enum.sort_by(rows, & &1.app, dir)
  defp sort_rows(rows, {:severity, dir}), do: Enum.sort_by(rows, &Status.rank(&1.severity), dir)

  @spec default_dir(atom()) :: :asc | :desc
  defp default_dir(:severity), do: :desc
  defp default_dir(_field), do: :asc

  @spec totals([row()]) :: %{atom() => non_neg_integer()}
  defp totals(rows) do
    %{
      deps: length(rows),
      advisories: Enum.count(rows, &row_matches?(&1, :advisory)),
      outdated: Enum.count(rows, &row_matches?(&1, :outdated)),
      retired: Enum.count(rows, &row_matches?(&1, :retired))
    }
  end

  @spec summary(%{atom() => non_neg_integer()}) :: String.t()
  defp summary(%{deps: 0}), do: "No dependencies are flagged under this lens."

  defp summary(%{deps: deps, advisories: advisories, outdated: outdated, retired: retired}) do
    "#{deps} #{plural(deps, "dependency", "dependencies")} flagged · " <>
      "#{advisories} #{plural(advisories, "advisory", "advisories")} · " <>
      "#{outdated} outdated · #{retired} retired"
  end

  @spec plural(non_neg_integer(), String.t(), String.t()) :: String.t()
  defp plural(1, singular, _plural), do: singular
  defp plural(_count, _singular, plural), do: plural

  @spec finding_class(Status.severity()) :: String.t()
  defp finding_class(:error), do: "text-red-700 dark:text-red-300"
  defp finding_class(:warning), do: "text-yellow-700 dark:text-yellow-300"
  defp finding_class(:info), do: "text-blue-700 dark:text-blue-300"
end
