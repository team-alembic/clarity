with {:module, Ash.Signals} <- Code.ensure_loaded(Ash.Signals) do
  defmodule Clarity.Content.Ash.SignalOverview do
    @moduledoc """
    The "Signal" tab: a signal's flow, payload, emitters and listeners.
    """

    @behaviour Clarity.Content

    use Clarity.Web, :live_component

    import Clarity.Components.OverviewComponents
    import Clarity.Content.Ash.Overview

    alias Clarity.Content.Ash.SignalFlow
    alias Clarity.Graph
    alias Clarity.Vertex
    alias Clarity.Vertex.Ash.Action
    alias Clarity.Vertex.Ash.Resource
    alias Clarity.Vertex.Ash.Signal
    alias Clarity.Vertex.Ash.SignalModule

    @impl Clarity.Content
    def name, do: "Signal"

    @impl Clarity.Content
    def description, do: "The signal's payload, emitters and listeners, and what follows from it"

    @impl Clarity.Content
    def sort_priority, do: -100

    @impl Clarity.Content
    def status_classes, do: [:integrity]

    @impl Clarity.Content
    def applies?(%Signal{}, _lens), do: true
    def applies?(_vertex, _lens), do: false

    @impl Phoenix.LiveComponent
    def update(assigns, socket) do
      %Signal{signal_module: module, signal: signal} = vertex = assigns.vertex
      graph = Map.get(assigns, :graph)

      {:ok,
       socket
       |> assign(assigns)
       |> assign(
         links: links(assigns),
         signal: signal,
         signal_module: module,
         payload: payload(signal),
         diagram: graph && IO.iodata_to_binary(SignalFlow.diagram(graph, [vertex])),
         emitters: emitters(graph, vertex),
         listeners: listeners(graph, vertex)
       )}
    end

    @impl Phoenix.LiveComponent
    def render(assigns) do
      ~H"""
      <div class="content w-full" id={@id}>
        <div class="ov-page">
          <div class="ov-head">
            <.hero vertex={@vertex} kind="Signal">
              <:badge :if={@signal.phase != :after_action}>
                <.flag kind={:plain} hint="When the signal is emitted">
                  {Signal.phase_text(@signal.phase)}
                </.flag>
              </:badge>
              <:headline>
                <span class="ov-phrase">
                  <span class="ov-muted">in</span>
                  <.vertex_link links={@links} vertex={%SignalModule{signal_module: @signal_module}} />
                </span>
              </:headline>
              <.description links={@links} text={description_of(@signal)} lead />
            </.hero>

            <.facts>
              <:fact label="Phase">
                <code class="ov-code">{inspect(@signal.phase)}</code>
              </:fact>
              <:fact label="Struct">
                <code class="ov-code">{inspect(@signal.struct)}</code>
              </:fact>
            </.facts>
          </div>

          <.section :if={@diagram} id="flow" title="Flow" icon="signal" tone="behaviour">
            <.mermaid id="signal-flow" graph={@diagram} class="h-80" />
          </.section>

          <.section id="payload" title="Payload" icon="attribute" tone="data" count={length(@payload)}>
            <.overview_table id="signal-payload" rows={@payload}>
              <:col :let={field} label="Name" class="w-0 whitespace-nowrap">
                <span class="ov-code">{field.name}</span>
              </:col>
              <:col :let={field} label="Type" class="w-0 whitespace-nowrap">
                <.ash_type links={@links} type={field.type} />
              </:col>
              <:col :let={field} label="About">
                <div class="ov-flags">
                  <.flag :if={not field.allow_nil?} text="required" />
                  <.flag :if={default(field)} hint="The value it takes when none is given">
                    default <code>{default(field)}</code>
                  </.flag>
                </div>
                <.description links={@links} text={description_of(field)} class="mt-0.5" />
              </:col>
            </.overview_table>
          </.section>

          <.section
            id="emitters"
            title="Emitters"
            icon="action"
            tone="behaviour"
            count={length(@emitters)}
          >
            <p :if={@emitters == []} class="ov-muted">No action emits this signal.</p>
            <.overview_table :if={@emitters != []} id="signal-emitters" rows={@emitters}>
              <:col :let={row} label="Action" class="w-0 whitespace-nowrap">
                <.vertex_link links={@links} vertex={%Resource{resource: row.action.resource}} />
                <.vertex_link links={@links} vertex={row.action} />
              </:col>
              <:col :let={row} label="Fills it with">
                <div :for={line <- emit_lines(row.emit)}>
                  <code class="ov-code">{line}</code>
                </div>
              </:col>
            </.overview_table>
          </.section>

          <.section
            id="listeners"
            title="Listeners"
            icon="action"
            tone="behaviour"
            count={length(@listeners)}
          >
            <p :if={@listeners == []} class="ov-muted">No listener.</p>
            <.overview_table :if={@listeners != []} id="signal-listeners" rows={@listeners}>
              <:col :let={row} label="Listener" class="w-0 whitespace-nowrap">
                <span class="ov-code">{row.listener.name}</span>
              </:col>
              <:col :let={row} label="Runs" class="w-0 whitespace-nowrap">
                <.vertex_link links={@links} vertex={%Resource{resource: row.action.resource}} />
                <.vertex_link links={@links} vertex={row.action} />
              </:col>
              <:col :let={row} label="Mapping">
                <div :for={line <- mapping_lines(row.listener)}>
                  <code class="ov-code">{line}</code>
                </div>
              </:col>
              <:col :let={row} label="Delivery">
                <code class="ov-code">{delivery_text(row.listener.delivery)}</code>
              </:col>
            </.overview_table>
          </.section>
        </div>
      </div>
      """
    end

    @spec payload(Ash.Signals.Signal.t()) :: [map()]
    defp payload(signal) do
      signal_id = %{
        name: :signal_id,
        type: Ash.Type.UUIDv7,
        allow_nil?: true,
        default: nil,
        description: "Ash sets it when the signal is emitted."
      }

      [signal_id | signal.arguments]
    end

    @spec emitters(Graph.t() | nil, Signal.t()) :: [%{action: Action.t(), emit: struct()}]
    defp emitters(nil, _vertex), do: []

    defp emitters(graph, vertex) do
      for %Action{} = action <-
            graph |> Graph.in_neighbors(vertex, :emits) |> Enum.sort_by(&Vertex.id/1),
          emit <- Signal.emits(vertex, action.action),
          do: %{action: action, emit: emit}
    end

    @spec listeners(Graph.t() | nil, Signal.t()) :: [%{action: Action.t(), listener: struct()}]
    defp listeners(nil, _vertex), do: []

    defp listeners(graph, vertex) do
      for {action, listener} <- Signal.listener_actions(graph, vertex),
          do: %{action: action, listener: listener}
    end

    @spec emit_lines(Ash.Resource.Actions.Emit.t()) :: [String.t()]
    defp emit_lines(%{dynamic?: true}), do: ["dynamic: the action's own code emits it"]

    defp emit_lines(emit) do
      lines =
        for {key, value} <- [fields: emit.fields, values: emit.values, where: emit.where],
            value != [],
            do: "#{key}: #{inspect(value)}"

      if lines == [], do: ["fields of the same name"], else: lines
    end

    @spec mapping_lines(Ash.Resource.SignalListener.t()) :: [String.t()]
    defp mapping_lines(listener) do
      lines =
        for key <- [:inputs, :get_by, :args, :read_action, :argument, :batch?],
            value = Map.fetch!(listener, key),
            value not in [nil, [], false],
            do: "#{key}: #{inspect(value)}"

      if lines == [], do: ["fields of the same name"], else: lines
    end

    @spec delivery_text({module(), keyword()} | module()) :: String.t()
    defp delivery_text({module, []}), do: inspect(module)
    defp delivery_text({module, options}), do: "#{inspect(module)} #{inspect(options)}"
    defp delivery_text(module), do: inspect(module)
  end
end
