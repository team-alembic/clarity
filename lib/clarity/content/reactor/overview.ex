with {:module, Reactor} <- Code.ensure_loaded(Reactor) do
  defmodule Clarity.Content.Reactor.Overview do
    @moduledoc """
    Content provider that draws every Reactor in a domain or application side
    by side, a card each, so its workflows can be seen at a glance. Each
    card's title opens the Reactor's own Reactor Flow tab
    (`Clarity.Content.Reactor.FlowDiagram`).

    A domain's Reactors are those `Clarity.Vertex.Reactor.domain/1` places in
    it; an application's are all of its modules that use Reactor.
    """

    @behaviour Clarity.Content

    use Clarity.Web, :live_component

    alias Clarity.Content
    alias Clarity.Content.Reactor.FlowDiagram
    alias Clarity.Vertex

    @impl Content
    def name, do: "Reactors"

    @impl Content
    def description, do: "Every Reactor here, side by side"

    @impl Content
    def sort_priority, do: -50

    @impl Content
    def applies?(vertex, _lens), do: reactors(vertex) != []

    @impl Phoenix.LiveComponent
    def update(assigns, socket) do
      {:ok, socket |> assign(assigns) |> assign(:reactors, reactors(assigns.vertex))}
    end

    @impl Phoenix.LiveComponent
    def render(assigns) do
      ~H"""
      <section class="content w-full p-4">
        <div class="grid grid-cols-1 gap-4">
          <article
            :for={reactor <- @reactors}
            data-reactor
            class="rounded-lg border border-base-light-300 dark:border-base-dark-700 bg-base-light-50 dark:bg-base-dark-800 p-4"
          >
            <h3 class="text-base font-semibold">
              <.link
                patch={tab_path(@prefix, @lens, reactor)}
                class="text-primary-light dark:text-primary-dark hover:underline"
              >
                {Vertex.Name.in_app(reactor)}
              </.link>
            </h3>
            <.mermaid
              id={"reactor-" <> String.replace(inspect(reactor), ".", "-")}
              graph={IO.iodata_to_binary(FlowDiagram.diagram(reactor))}
              data-pan-zoom="false"
              class="h-80 mt-3"
            />
          </article>
        </div>
      </section>
      """
    end

    # Matched by struct name, so this compiles where Reactor is used without Ash.
    @spec reactors(Vertex.t()) :: [module()]
    defp reactors(%{__struct__: Vertex.Ash.Domain, domain: domain}) do
      domain
      |> Application.get_application()
      |> reactors_in()
      |> Enum.filter(&(Vertex.Reactor.domain(&1) == domain))
    end

    defp reactors(%Vertex.Application{app: app}), do: reactors_in(app)
    defp reactors(_vertex), do: []

    @spec reactors_in(Application.app() | nil) :: [module()]
    defp reactors_in(app) do
      (Application.spec(app, :modules) || [])
      |> Enum.filter(&Vertex.Reactor.reactor?/1)
      |> Enum.sort_by(&Vertex.Name.in_app/1)
    end

    @spec tab_path(String.t(), Clarity.Perspective.Lens.t(), module()) :: String.t()
    defp tab_path(prefix, lens, reactor) do
      Path.join([
        prefix,
        lens.id,
        Vertex.id(%Vertex.Reactor{reactor: reactor}),
        Content.content_id(FlowDiagram)
      ])
    end
  end
end
