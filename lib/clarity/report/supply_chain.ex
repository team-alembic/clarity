defmodule Clarity.Report.SupplyChain do
  @moduledoc """
  Supply-chain security report: every dependency flagged by
  `Clarity.Status.SupplyChain` — a security advisory, or an outdated/retired
  version — rolled up into one view under the security lens.
  """

  @behaviour Clarity.Report

  use Clarity.Web, :live_component

  alias Clarity.Advisory.Source
  alias Clarity.Graph
  alias Clarity.Perspective.Lens
  alias Clarity.Status
  alias Clarity.Vertex

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
     |> assign(rows: rows, totals: totals(rows), refreshed_at: Source.last_refreshed_at())}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <section>
      <h2 class="text-2xl font-bold mb-1">Supply chain security</h2>
      <p class="opacity-70 mb-4">{summary(@totals)}</p>
      <p :if={@refreshed_at} class="text-sm italic opacity-60 mb-4">
        Advisory data as of {Calendar.strftime(@refreshed_at, "%-d %B %Y %H:%M UTC")}.
      </p>

      <%= if @rows == [] do %>
        <p class="opacity-70">No flagged dependencies under this lens.</p>
      <% else %>
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left border-b border-base-light-300 dark:border-base-dark-700">
              <th class="py-2 pr-4 font-semibold">Dependency</th>
              <th class="py-2 pr-4 font-semibold">Installed</th>
              <th class="py-2 font-semibold">Findings</th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={{vertex, statuses} <- @rows}
              class="border-b border-base-light-200 dark:border-base-dark-800 align-top"
            >
              <td class="py-2 pr-4 font-medium">
                <.link
                  patch={Path.join([@prefix, @lens.id, Vertex.id(vertex)])}
                  class="text-primary-light dark:text-primary-dark hover:underline"
                >
                  {vertex.app}
                </.link>
              </td>
              <td class="py-2 pr-4 tabular-nums">{vertex.version}</td>
              <td class="py-2">
                <ul class="space-y-1">
                  <li :for={status <- statuses} class={finding_class(status.severity)}>
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

  @spec build_rows(Graph.t(), Lens.t()) :: [{Vertex.Application.t(), [Status.t()]}]
  defp build_rows(graph, lens) do
    graph
    |> Graph.vertices({:==, :vertex_type, Vertex.Application})
    |> Enum.map(fn vertex ->
      {vertex, Enum.filter(Status.SupplyChain.statuses(vertex, graph), lens.status_filter)}
    end)
    |> Enum.reject(fn {_vertex, statuses} -> statuses == [] end)
    |> Enum.sort_by(fn {vertex, _statuses} -> to_string(vertex.app) end)
  end

  @spec totals([{Vertex.Application.t(), [Status.t()]}]) :: %{atom() => non_neg_integer()}
  defp totals(rows) do
    statuses = Enum.flat_map(rows, fn {_vertex, statuses} -> statuses end)

    %{
      deps: length(rows),
      advisories: Enum.count(statuses, &(&1.class == :security)),
      outdated: Enum.count(statuses, &(&1.class == :hygiene and &1.severity == :info)),
      retired: Enum.count(statuses, &(&1.class == :hygiene and &1.severity == :warning))
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
