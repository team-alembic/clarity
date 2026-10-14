with {:module, Ash.Signals} <- Code.ensure_loaded(Ash.Signals) do
  defmodule Clarity.Introspector.Ash.Signal do
    @moduledoc false

    @behaviour Clarity.Introspector

    alias Ash.Signals.Info
    alias Clarity.Config
    alias Clarity.Graph
    alias Clarity.Introspector.Parent
    alias Clarity.Vertex
    alias Clarity.Vertex.Ash.Action
    alias Clarity.Vertex.Ash.Domain
    alias Clarity.Vertex.Ash.Resource
    alias Clarity.Vertex.Ash.Signal
    alias Clarity.Vertex.Ash.SignalModule
    alias Clarity.Vertex.Util

    @impl Clarity.Introspector
    def source_vertex_types, do: [Vertex.Module, Domain, SignalModule, Signal, Action]

    @impl Clarity.Introspector
    def introspect_vertex(%Vertex.Module{module: module} = module_vertex, graph) do
      if SignalModule.signal_module?(module) do
        signal_module_vertex = %SignalModule{signal_module: module}

        with {:ok, parent} <- Parent.vertex(module, SignalModule.domain(module), graph) do
          {:ok,
           [
             {:vertex, signal_module_vertex},
             {:edge, parent, signal_module_vertex, :signal_module},
             {:edge, module_vertex, signal_module_vertex, :signal_module}
           ]}
        end
      else
        {:ok, []}
      end
    end

    def introspect_vertex(%Domain{domain: domain} = domain_vertex, graph) do
      edges =
        for %SignalModule{signal_module: module} = signal_module_vertex <-
              Graph.vertices(graph, {:==, :vertex_type, SignalModule}),
            SignalModule.domain(module) == domain,
            edge = {:edge, domain_vertex, signal_module_vertex, :signal_module},
            not linked?(graph, edge),
            do: edge

      {:ok, edges}
    end

    def introspect_vertex(%SignalModule{signal_module: module} = signal_module_vertex, _graph) do
      entries =
        for signal <- Info.signals(module),
            signal_vertex = %Signal{signal_module: module, signal: signal},
            entry <- [
              {:vertex, signal_vertex},
              {:edge, signal_module_vertex, signal_vertex, :signal}
            ],
            do: entry

      {:ok, entries}
    end

    def introspect_vertex(
          %Signal{signal_module: module, signal: %{name: name}} = signal_vertex,
          graph
        ) do
      resources =
        for %Resource{resource: resource} <- Graph.vertices(graph, {:==, :vertex_type, Resource}),
            uses?(resource, module),
            do: resource

      actions =
        Graph.vertices(
          graph,
          {:and, {:==, :vertex_type, Action}, {:in, {:field, :resource}, resources}}
        )

      edges =
        for %Action{} = action_vertex <- actions,
            {label, ^module, ^name} <-
              Signal.references(action_vertex.resource, action_vertex.action),
            edge = edge(label, action_vertex, signal_vertex),
            not linked?(graph, edge),
            do: edge

      {:ok, edges}
    end

    def introspect_vertex(%Action{action: action, resource: resource} = action_vertex, graph) do
      resolved =
        for {label, module, name} <- Signal.references(resource, action),
            do: {label, resolve(graph, module, name)}

      case for({_label, {:missing, module}} <- resolved, do: module) do
        [] ->
          edges =
            for {label, {:ok, signal_vertex}} <- resolved,
                edge = edge(label, action_vertex, signal_vertex),
                not linked?(graph, edge),
                do: edge

          {:ok, edges}

        missing ->
          {:error, {:unmet_dependencies, Enum.uniq(missing)}}
      end
    end

    @spec resolve(Graph.t(), module(), atom()) ::
            {:ok, Signal.t()} | {:missing, module()} | :broken
    defp resolve(graph, module, name) do
      with true <- SignalModule.signal_module?(module),
           %{} <- Info.signal(module, name),
           true <- Config.should_process_module?(module) do
        case Graph.get_vertex(graph, Util.id(Signal, [module, name])) do
          nil -> {:missing, module}
          signal_vertex -> {:ok, signal_vertex}
        end
      else
        _broken -> :broken
      end
    end

    @spec uses?(Ash.Resource.t(), module()) :: boolean()
    defp uses?(resource, module) do
      module in Ash.Resource.Info.signals_out(resource) or
        Enum.any?(Ash.Resource.Info.signal_listeners(resource), &(&1.signal_module == module))
    end

    @spec edge(:emits | :triggers, Action.t(), Signal.t()) :: Clarity.Introspector.entry()
    defp edge(:emits, action_vertex, signal_vertex),
      do: {:edge, action_vertex, signal_vertex, :emits}

    defp edge(:triggers, action_vertex, signal_vertex),
      do: {:edge, signal_vertex, action_vertex, :triggers}

    @spec linked?(Graph.t(), Clarity.Introspector.entry()) :: boolean()
    defp linked?(graph, {:edge, from, to, label}) do
      to_id = Vertex.id(to)
      graph |> Graph.out_neighbors(from, label) |> Enum.any?(&(Vertex.id(&1) == to_id))
    end
  end
end
