with {:module, Ash.Signals} <- Code.ensure_loaded(Ash.Signals) do
  defmodule Clarity.Content.Ash.SignalFlow do
    @moduledoc """
    Draws Ash signals as a Mermaid flowchart. The chart shows the actions
    that emit the given signals. Then it follows each chain forward to its
    end: listener, the signals that the listener emits, their listeners, and
    so on.

    - A solid line to a listener means `Ash.Signals.Delivery.Inline`. A
      dashed line means another delivery, for example a job queue.
    - A signal shows its phase when the phase is not `:after_action`.
    - The given signals have a thick outline.
    """

    alias Clarity.Graph
    alias Clarity.Vertex
    alias Clarity.Vertex.Ash.Action
    alias Clarity.Vertex.Ash.Signal

    @typep flow() :: %{
             signals: %{String.t() => Signal.t()},
             actions: %{String.t() => Action.t()},
             followed: MapSet.t(String.t()),
             emits: MapSet.t({String.t(), String.t()}),
             triggers: MapSet.t({String.t(), String.t(), module()})
           }

    @doc "Returns the Mermaid flowchart of `seeds`, their emitters and what follows them."
    @spec diagram(Graph.t(), [Signal.t()]) :: iodata()
    def diagram(graph, seeds) do
      empty = %{
        signals: %{},
        actions: %{},
        followed: MapSet.new(),
        emits: MapSet.new(),
        triggers: MapSet.new()
      }

      flow =
        seeds
        |> Enum.reduce(empty, &put_emitters(graph, &1, &2))
        |> follow(graph, seeds)

      seed_ids = MapSet.new(seeds, &Vertex.id/1)

      outlines =
        for {id, signal} <- Enum.sort(flow.signals),
            MapSet.member?(seed_ids, id),
            do: ["  class ", node_id(signal), " seed\n"]

      [
        "flowchart LR\n",
        "  classDef seed stroke-width:3px;\n",
        flow.actions |> Map.values() |> Enum.sort_by(&action_label/1) |> Enum.map(&action_node/1),
        flow.signals |> Map.values() |> Enum.sort_by(&node_id/1) |> Enum.map(&signal_node/1),
        flow.emits |> Enum.sort() |> Enum.map(&emit_line(flow, &1)),
        flow.triggers |> Enum.sort() |> Enum.map(&trigger_line(flow, &1)),
        outlines
      ]
    end

    @spec put_emitters(Graph.t(), Signal.t(), flow()) :: flow()
    defp put_emitters(graph, signal, flow) do
      emitters = Graph.in_neighbors(graph, signal, :emits)

      flow
      |> put_signal(signal)
      |> put_actions(emitters)
      |> Map.update!(:emits, fn emits ->
        Enum.reduce(emitters, emits, &MapSet.put(&2, {Vertex.id(&1), Vertex.id(signal)}))
      end)
    end

    @spec follow(flow(), Graph.t(), [Signal.t()]) :: flow()
    defp follow(flow, _graph, []), do: flow

    defp follow(flow, graph, [signal | rest]) do
      signal_id = Vertex.id(signal)

      if MapSet.member?(flow.followed, signal_id) do
        follow(flow, graph, rest)
      else
        triggered = Signal.listener_actions(graph, signal)
        listeners = triggered |> Enum.map(&elem(&1, 0)) |> Enum.uniq_by(&Vertex.id/1)

        emitted =
          for action <- listeners,
              next <- Graph.out_neighbors(graph, action, :emits),
              do: {action, next}

        flow
        |> put_signal(signal)
        |> Map.update!(:followed, &MapSet.put(&1, signal_id))
        |> put_actions(listeners)
        |> put_triggers(signal_id, triggered)
        |> put_emitted(emitted)
        |> follow(graph, Enum.map(emitted, &elem(&1, 1)) ++ rest)
      end
    end

    @spec put_triggers(flow(), String.t(), [{Action.t(), Ash.Resource.SignalListener.t()}]) ::
            flow()
    defp put_triggers(flow, signal_id, triggered) do
      triggers =
        Enum.reduce(triggered, flow.triggers, fn {action, listener}, triggers ->
          delivery = Signal.delivery_module(listener.delivery)
          MapSet.put(triggers, {signal_id, Vertex.id(action), delivery})
        end)

      %{flow | triggers: triggers}
    end

    @spec put_emitted(flow(), [{Action.t(), Signal.t()}]) :: flow()
    defp put_emitted(flow, emitted) do
      Enum.reduce(emitted, flow, fn {action, signal}, flow ->
        flow
        |> put_signal(signal)
        |> Map.update!(:emits, &MapSet.put(&1, {Vertex.id(action), Vertex.id(signal)}))
      end)
    end

    @spec put_signal(flow(), Signal.t()) :: flow()
    defp put_signal(flow, signal),
      do: %{flow | signals: Map.put(flow.signals, Vertex.id(signal), signal)}

    @spec put_actions(flow(), [Action.t()]) :: flow()
    defp put_actions(flow, actions),
      do: %{flow | actions: Enum.reduce(actions, flow.actions, &Map.put(&2, Vertex.id(&1), &1))}

    @spec emit_line(flow(), {String.t(), String.t()}) :: iodata()
    defp emit_line(flow, {action_id, signal_id}),
      do: [
        "  ",
        node_id(flow.actions[action_id]),
        " --> ",
        node_id(flow.signals[signal_id]),
        "\n"
      ]

    @spec trigger_line(flow(), {String.t(), String.t(), module()}) :: iodata()
    defp trigger_line(flow, {signal_id, action_id, delivery}),
      do: [
        "  ",
        node_id(flow.signals[signal_id]),
        arrow(delivery),
        node_id(flow.actions[action_id]),
        "\n"
      ]

    @spec arrow(module()) :: String.t()
    defp arrow(Ash.Signals.Delivery.Inline), do: " --> "
    defp arrow(_delivery), do: " -.-> "

    @spec action_node(Action.t()) :: iodata()
    defp action_node(action), do: ["  ", node_id(action), "[\"", action_label(action), "\"]\n"]

    @spec signal_node(Signal.t()) :: iodata()
    defp signal_node(%Signal{signal: signal} = vertex),
      do: ["  ", node_id(vertex), "{{\"", signal_label(signal), "\"}}\n"]

    @spec signal_label(Ash.Signals.Signal.t()) :: iodata()
    defp signal_label(%{name: name, phase: :after_action}), do: Atom.to_string(name)

    defp signal_label(%{name: name, phase: phase}),
      do: [Atom.to_string(name), "<br/><i>", Signal.phase_text(phase), "</i>"]

    @spec action_label(Action.t()) :: String.t()
    defp action_label(%Action{action: action, resource: resource}),
      do: Vertex.Name.in_app(resource) <> "." <> Atom.to_string(action.name)

    @doc false
    @spec node_id(Action.t() | Signal.t()) :: String.t()
    def node_id(%Action{action: action, resource: resource}),
      do: "a_" <> safe(inspect(resource) <> "." <> Atom.to_string(action.name))

    def node_id(%Signal{signal_module: module, signal: %{name: name}}),
      do: "s_" <> safe(inspect(module) <> "." <> Atom.to_string(name))

    @spec safe(String.t()) :: String.t()
    defp safe(name) do
      hash = name |> :erlang.phash2() |> Integer.to_string(36)
      String.replace(name, ~r/\W/u, "_") <> "_" <> hash
    end
  end
end
