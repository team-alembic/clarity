with {:module, AshStateMachine} <- Code.ensure_loaded(AshStateMachine) do
  defmodule Clarity.Content.Ash.StateMachinesOverview do
    @moduledoc """
    Content provider that draws every `AshStateMachine` resource in a domain or
    application side by side, a card each, so its lifecycles can be seen at a
    glance. Each card's title opens the resource's own State Machine tab
    (`Clarity.Content.Ash.StateMachineDiagram`).
    """

    @behaviour Clarity.Content

    use Clarity.Web, :live_component

    alias Clarity.Content
    alias Clarity.Content.Ash.StateMachineDiagram
    alias Clarity.Vertex

    @impl Content
    def name, do: "State Machines"

    @impl Content
    def description, do: "Every state machine here, side by side"

    @impl Content
    def sort_priority, do: -50

    @impl Content
    def applies?(vertex, _lens), do: state_machines(vertex) != []

    @impl Phoenix.LiveComponent
    def update(assigns, socket) do
      {:ok, socket |> assign(assigns) |> assign(:state_machines, state_machines(assigns.vertex))}
    end

    @impl Phoenix.LiveComponent
    def render(assigns) do
      ~H"""
      <section class="content w-full p-4">
        <div class="grid grid-cols-1 xl:grid-cols-2 gap-4">
          <article
            :for={resource <- @state_machines}
            data-state-machine
            class="rounded-lg border border-base-light-300 dark:border-base-dark-700 bg-base-light-50 dark:bg-base-dark-800 p-4"
          >
            <h3 class="text-base font-semibold">
              <.link
                patch={tab_path(@prefix, @lens, resource)}
                class="text-primary-light dark:text-primary-dark hover:underline"
              >
                {Vertex.Name.in_app(resource)}
              </.link>
            </h3>
            <.mermaid
              id={"state-machine-" <> String.replace(inspect(resource), ".", "-")}
              graph={IO.iodata_to_binary(StateMachineDiagram.diagram(resource))}
              data-pan-zoom="false"
              class="h-56 mt-3"
            />
          </article>
        </div>
      </section>
      """
    end

    # Resources using AshStateMachine, in a domain or in an application's
    # domains, sorted by the name each card shows.
    @spec state_machines(Vertex.t()) :: [Ash.Resource.t()]
    defp state_machines(%Vertex.Ash.Domain{domain: domain}), do: state_machines_in([domain])

    defp state_machines(%Vertex.Application{app: app}),
      do: app |> Ash.Info.domains() |> state_machines_in()

    defp state_machines(_vertex), do: []

    @spec state_machines_in([Ash.Domain.t()]) :: [Ash.Resource.t()]
    defp state_machines_in(domains) do
      domains
      |> Enum.flat_map(&Ash.Domain.Info.resources/1)
      |> Enum.filter(&StateMachineDiagram.state_machine?/1)
      |> Enum.uniq()
      |> Enum.sort_by(&Vertex.Name.in_app/1)
    end

    @spec tab_path(String.t(), Clarity.Perspective.Lens.t(), Ash.Resource.t()) :: String.t()
    defp tab_path(prefix, lens, resource) do
      Path.join([
        prefix,
        lens.id,
        Vertex.id(%Vertex.Ash.Resource{resource: resource}),
        Content.content_id(StateMachineDiagram)
      ])
    end
  end
end
