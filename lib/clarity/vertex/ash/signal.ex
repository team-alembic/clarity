with {:module, Ash.Signals} <- Code.ensure_loaded(Ash.Signals) do
  defmodule Clarity.Vertex.Ash.Signal do
    @moduledoc """
    Vertex for one signal of an `Ash.Signals` module.
    """

    alias Ash.Resource.Info
    alias Ash.Signals.Signal
    alias Clarity.SourceLocation
    alias Clarity.Vertex.HintProvider

    @type t() :: %__MODULE__{signal_module: module(), signal: Signal.t()}
    @enforce_keys [:signal_module, :signal]
    defstruct [:signal_module, :signal]

    @typedoc """
    `:emits` when the action emits the signal. `:triggers` when a listener
    runs the action for the signal.
    """
    @type signal_reference() :: {:emits | :triggers, signal_module :: module(), signal :: atom()}

    @doc "Returns the signals that the action emits, then the signals that listeners run it for."
    @spec references(Ash.Resource.t(), struct() | map()) :: [signal_reference()]
    def references(resource, action) do
      emits =
        for emit <- Map.get(action, :emits, []),
            do: {:emits, emit.signal_module, emit.signal}

      triggers =
        for listener <- Info.signal_listeners(resource),
            listener.action == action.name,
            do: {:triggers, listener.signal_module, listener.signal}

      Enum.uniq(emits ++ triggers)
    end

    @doc "Returns the listeners on the resource that run the named action for the signal."
    @spec listeners(t(), Ash.Resource.t(), atom()) :: [Ash.Resource.SignalListener.t()]
    def listeners(
          %__MODULE__{signal_module: module, signal: %{name: name}},
          resource,
          action_name
        ) do
      for listener <- Info.signal_listeners(resource),
          listener.signal_module == module,
          listener.signal == name,
          listener.action == action_name,
          do: listener
    end

    @doc "Returns the action's `emit` entries for the signal."
    @spec emits(t(), struct() | map()) :: [Ash.Resource.Actions.Emit.t()]
    def emits(%__MODULE__{signal_module: module, signal: %{name: name}}, action) do
      for emit <- Map.get(action, :emits, []),
          emit.signal_module == module,
          emit.signal == name,
          do: emit
    end

    @doc "Returns the module of a listener's delivery."
    @spec delivery_module({module(), keyword()} | module()) :: module()
    def delivery_module({module, _options}) when is_atom(module), do: module
    def delivery_module(module) when is_atom(module), do: module

    @doc ~S'Returns the phase as words, for example `"after transaction"`.'
    @spec phase_text(atom()) :: String.t()
    def phase_text(phase), do: phase |> Atom.to_string() |> String.replace("_", " ")

    defimpl Clarity.Vertex do
      alias Clarity.Vertex.Util

      @impl Clarity.Vertex
      def id(%@for{signal_module: module, signal: %{name: name}}),
        do: Util.id(@for, [module, name])

      @impl Clarity.Vertex
      def type_label(_vertex), do: inspect(Signal)

      @impl Clarity.Vertex
      def name(%@for{signal: %{name: name}}), do: Atom.to_string(name)
    end

    defimpl Clarity.Vertex.GraphShapeProvider do
      @impl Clarity.Vertex.GraphShapeProvider
      def shape(_vertex), do: "hexagon"
    end

    defimpl Clarity.Vertex.SourceLocationProvider do
      @impl Clarity.Vertex.SourceLocationProvider
      def source_location(%@for{signal_module: module, signal: signal}),
        do: SourceLocation.from_spark_entity(module, signal)
    end

    defimpl Clarity.Vertex.TooltipProvider do
      @impl Clarity.Vertex.TooltipProvider
      def tooltip(%@for{signal_module: module, signal: signal}) do
        [
          "Signal: `",
          inspect(signal.name),
          "` in `",
          inspect(module),
          "`\n\n",
          if(signal.description, do: [signal.description, "\n\n"], else: []),
          "Phase: `",
          inspect(signal.phase),
          "`"
        ]
      end
    end

    defimpl Clarity.Vertex.HintProvider do
      @impl HintProvider
      def icon(_vertex), do: :signal

      @impl HintProvider
      def badges(_vertex), do: []

      @impl HintProvider
      def facts(%@for{signal: signal}) do
        [
          {"Phase", Atom.to_string(signal.phase)},
          {"Payload", ["signal_id" | Enum.map(signal.arguments, &Atom.to_string(&1.name))]}
        ]
      end
    end
  end
end
