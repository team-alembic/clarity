with {:module, Ash.Signals} <- Code.ensure_loaded(Ash.Signals) do
  defmodule Clarity.Content.Ash.SignalsOverview do
    @moduledoc """
    The "Signals" tab: the flow and a table of the signals that an action,
    resource, signal module, domain or application emits, listens to or
    declares.
    """

    @behaviour Clarity.Content

    use Clarity.Web, :live_component

    import Clarity.Components.OverviewComponents

    alias Ash.Signals.Info
    alias Clarity.Content.Ash.SignalFlow
    alias Clarity.Graph
    alias Clarity.Vertex
    alias Clarity.Vertex.Ash.Action
    alias Clarity.Vertex.Ash.Domain
    alias Clarity.Vertex.Ash.Resource
    alias Clarity.Vertex.Ash.Signal
    alias Clarity.Vertex.Ash.SignalModule
    alias Clarity.Vertex.Util

    @impl Clarity.Content
    def name, do: "Signals"

    @impl Clarity.Content
    def description, do: "The signals here, and what follows from them"

    @impl Clarity.Content
    def sort_priority, do: -50

    @impl Clarity.Content
    def status_classes, do: [:integrity]

    @impl Clarity.Content
    def applies?(vertex, _lens), do: signals(vertex) != []

    @impl Phoenix.LiveComponent
    def update(assigns, socket) do
      graph = Map.get(assigns, :graph)
      seeds = seeds(graph, assigns.vertex)

      {:ok,
       socket
       |> assign(assigns)
       |> assign(
         links: links(assigns),
         diagram: seeds != [] && IO.iodata_to_binary(SignalFlow.diagram(graph, seeds)),
         rows: Enum.map(seeds, &row(graph, &1))
       )}
    end

    @impl Phoenix.LiveComponent
    def render(assigns) do
      ~H"""
      <div class="content w-full" id={@id}>
        <div class="ov-page">
          <.section :if={@diagram} id="flow" title="Flow" icon="signal" tone="behaviour">
            <.mermaid id="signals-flow" graph={@diagram} class="h-80" />
          </.section>

          <.section id="signals" title="Signals" icon="signal" tone="behaviour" count={length(@rows)}>
            <.overview_table id="signals-table" rows={@rows}>
              <:col :let={row} label="Signal" class="w-0 whitespace-nowrap">
                <.vertex_link links={@links} vertex={row.signal} code />
              </:col>
              <:col :let={row} label="Phase" class="w-0 whitespace-nowrap">
                {Signal.phase_text(row.signal.signal.phase)}
              </:col>
              <:col :let={row} label="Emitters" class="w-0 whitespace-nowrap">
                {row.emitters}
              </:col>
              <:col :let={row} label="Listeners" class="w-0 whitespace-nowrap">
                {row.listeners}
              </:col>
              <:col :let={row} label="Deliveries">
                <div :for={delivery <- row.deliveries}>
                  <code class="ov-code">{delivery}</code>
                </div>
              </:col>
            </.overview_table>
          </.section>
        </div>
      </div>
      """
    end

    @spec seeds(Graph.t() | nil, Vertex.t()) :: [Signal.t()]
    defp seeds(nil, _vertex), do: []

    defp seeds(graph, vertex) do
      for {module, name} <- signals(vertex),
          %Signal{} = signal <- [Graph.get_vertex(graph, Util.id(Signal, [module, name]))],
          do: signal
    end

    @spec row(Graph.t(), Signal.t()) :: map()
    defp row(graph, signal) do
      listeners = for {_action, listener} <- Signal.listener_actions(graph, signal), do: listener

      %{
        signal: signal,
        emitters: length(Graph.in_neighbors(graph, signal, :emits)),
        listeners: length(listeners),
        deliveries:
          listeners
          |> Enum.map(&(&1.delivery |> Signal.delivery_module() |> inspect()))
          |> Enum.uniq()
          |> Enum.sort()
      }
    end

    @spec signals(Vertex.t()) :: [{module(), atom()}]
    defp signals(vertex) do
      vertex
      |> references()
      |> Enum.uniq()
      |> Enum.filter(fn {module, name} ->
        SignalModule.signal_module?(module) and Info.signal(module, name) != nil
      end)
      |> Enum.sort_by(fn {module, name} -> {name, inspect(module)} end)
    end

    @spec references(Vertex.t()) :: [{module(), atom()}]
    defp references(%Action{action: action, resource: resource}),
      do: action_references(resource, [action])

    defp references(%Resource{resource: resource}), do: resource_references([resource])
    defp references(%SignalModule{signal_module: module}), do: declared([module])

    defp references(%Domain{domain: domain}) do
      modules =
        domain
        |> Clarity.Config.application_of()
        |> SignalModule.in_app()
        |> Enum.filter(&(SignalModule.domain(&1) == domain))

      declared(modules) ++ resource_references(Ash.Domain.Info.resources(domain))
    end

    defp references(%Vertex.Application{app: app}) do
      resources = app |> Ash.Info.domains() |> Enum.flat_map(&Ash.Domain.Info.resources/1)
      declared(SignalModule.in_app(app)) ++ resource_references(resources)
    end

    defp references(_vertex), do: []

    @spec declared([module()]) :: [{module(), atom()}]
    defp declared(modules) do
      for module <- modules, signal <- Info.signals(module), do: {module, signal.name}
    end

    @spec resource_references([Ash.Resource.t()]) :: [{module(), atom()}]
    defp resource_references(resources),
      do: Enum.flat_map(resources, &action_references(&1, Ash.Resource.Info.actions(&1)))

    @spec action_references(Ash.Resource.t(), [struct()]) :: [{module(), atom()}]
    defp action_references(resource, actions) do
      for action <- actions,
          {_label, module, name} <- Signal.references(resource, action),
          do: {module, name}
    end
  end
end
