with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Report.SecurityPosture do
    @moduledoc """
    Security posture report: every Ash resource under the security lens, rolled up
    with its enforcement (policy authorizer / open / bypass) and sensitive-field
    exposure. Filter to the resources that carry a concern.
    """

    @behaviour Clarity.Report

    use Clarity.Web, :live_component

    alias Ash.Policy.Info, as: PolicyInfo
    alias Ash.Resource.Info
    alias Clarity.Graph
    alias Clarity.Perspective.Lens
    alias Clarity.Vertex
    alias Clarity.Vertex.Ash.Resource
    alias Phoenix.LiveView.Rendered

    @authorizer Ash.Policy.Authorizer

    @type row() :: %{
            vertex: Resource.t(),
            name: String.t(),
            governed?: boolean(),
            bypass?: boolean(),
            sensitive: non_neg_integer(),
            exposed: non_neg_integer()
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
      rows = build_rows(assigns.graph)

      {:ok,
       socket
       |> assign(prefix: assigns.prefix, lens: assigns.lens)
       |> assign(rows: rows, totals: totals(rows))
       |> assign_new(:filter, fn -> :all end)}
    end

    @impl Phoenix.LiveComponent
    def handle_event("filter", %{"kind" => kind}, socket) do
      {:noreply, assign(socket, filter: String.to_existing_atom(kind))}
    end

    @impl Phoenix.LiveComponent
    def render(assigns) do
      assigns = assign(assigns, :visible, filter_rows(assigns.rows, assigns.filter))

      ~H"""
      <section>
        <h2 class="text-2xl font-bold mb-1">Security posture</h2>
        <p class="opacity-70 mb-4">{summary(@totals)}</p>

        <%= if @rows == [] do %>
          <p class="opacity-70">No Ash resources are visible under this lens.</p>
        <% else %>
          <div class="flex flex-wrap gap-1 mb-4">
            <.chip myself={@myself} kind={:all} active={@filter} label="All" count={@totals.resources} />
            <.chip
              myself={@myself}
              kind={:unprotected}
              active={@filter}
              label="Open"
              count={@totals.unprotected}
            />
            <.chip
              myself={@myself}
              kind={:bypass}
              active={@filter}
              label="Bypass"
              count={@totals.bypass}
            />
            <.chip
              myself={@myself}
              kind={:exposed}
              active={@filter}
              label="Exposed fields"
              count={@totals.exposed}
            />
          </div>

          <table class="w-full text-sm">
            <thead>
              <tr class="text-left border-b border-base-light-300 dark:border-base-dark-700">
                <th class="py-2 pr-4 font-semibold">Resource</th>
                <th class="py-2 pr-4 font-semibold">Enforcement</th>
                <th class="py-2 pr-4 font-semibold">Bypass</th>
                <th class="py-2 font-semibold">Sensitive fields</th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={row <- @visible}
                class="border-b border-base-light-200 dark:border-base-dark-800"
              >
                <td class="py-2 pr-4 font-medium">
                  <.link
                    patch={Path.join([@prefix, @lens.id, Vertex.id(row.vertex)])}
                    class="text-primary-light dark:text-primary-dark hover:underline"
                  >
                    {row.name}
                  </.link>
                </td>
                <td class="py-2 pr-4">
                  <span :if={row.governed?} class="text-green-700 dark:text-green-300">Governed</span>
                  <span :if={not row.governed?} class="text-yellow-700 dark:text-yellow-300">
                    ⚠ Open
                  </span>
                </td>
                <td class="py-2 pr-4">
                  <span :if={row.bypass?} class="text-blue-700 dark:text-blue-300">⚠ Bypass</span>
                  <span :if={not row.bypass?} class="opacity-50">—</span>
                </td>
                <td class="py-2">
                  <span
                    :if={row.exposed > 0}
                    class="text-red-700 dark:text-red-300"
                  >{row.exposed} exposed</span>
                  <span class="opacity-60">
                    <span :if={row.exposed > 0}>/</span> {row.sensitive} sensitive
                  </span>
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

    @spec build_rows(Graph.t()) :: [row()]
    defp build_rows(graph) do
      graph
      |> Graph.vertices({:==, :vertex_type, Resource})
      |> Enum.map(&build_row/1)
      |> Enum.sort_by(& &1.name)
    end

    @spec build_row(Resource.t()) :: row()
    defp build_row(%Resource{resource: resource} = vertex) do
      sensitive = Enum.filter(Info.attributes(resource), & &1.sensitive?)

      %{
        vertex: vertex,
        name: Vertex.name(vertex),
        governed?: @authorizer in Info.authorizers(resource),
        bypass?: Enum.any?(PolicyInfo.policies(resource), & &1.bypass?),
        sensitive: length(sensitive),
        exposed: Enum.count(sensitive, &exposed?(&1, resource))
      }
    end

    @spec exposed?(Ash.Resource.Attribute.t(), Ash.Resource.t()) :: boolean()
    defp exposed?(attribute, resource) do
      attribute.public? and
        PolicyInfo.field_policies_for_field(resource, attribute.name) in [nil, []]
    end

    @spec filter_rows([row()], atom()) :: [row()]
    defp filter_rows(rows, :all), do: rows
    defp filter_rows(rows, :unprotected), do: Enum.reject(rows, & &1.governed?)
    defp filter_rows(rows, :bypass), do: Enum.filter(rows, & &1.bypass?)
    defp filter_rows(rows, :exposed), do: Enum.filter(rows, &(&1.exposed > 0))

    @spec totals([row()]) :: %{atom() => non_neg_integer()}
    defp totals(rows) do
      %{
        resources: length(rows),
        unprotected: Enum.count(rows, &(not &1.governed?)),
        bypass: Enum.count(rows, & &1.bypass?),
        exposed: Enum.count(rows, &(&1.exposed > 0))
      }
    end

    @spec summary(%{atom() => non_neg_integer()}) :: String.t()
    defp summary(%{resources: 0}), do: "No Ash resources are visible under this lens."

    defp summary(totals) do
      "#{totals.resources} #{plural(totals.resources, "resource", "resources")} · " <>
        "#{totals.unprotected} open · #{totals.bypass} with bypass · " <>
        "#{totals.exposed} with exposed fields"
    end

    @spec plural(non_neg_integer(), String.t(), String.t()) :: String.t()
    defp plural(1, singular, _plural), do: singular
    defp plural(_count, _singular, plural), do: plural
  end
end
