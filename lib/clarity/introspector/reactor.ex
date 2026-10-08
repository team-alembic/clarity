with {:module, Reactor} <- Code.ensure_loaded(Reactor) do
  defmodule Clarity.Introspector.Reactor do
    @moduledoc false

    @behaviour Clarity.Introspector

    alias Clarity.Config
    alias Clarity.Vertex
    alias Clarity.Vertex.Ash.Action
    alias Clarity.Vertex.Ash.Domain
    alias Clarity.Vertex.Module
    alias Clarity.Vertex.Util

    @impl Clarity.Introspector
    def source_vertex_types, do: [Module, Action, Domain]

    @impl Clarity.Introspector
    def introspect_vertex(%Module{module: module} = module_vertex, graph) do
      if Vertex.Reactor.reactor?(module) do
        reactor_vertex = %Vertex.Reactor{reactor: module}

        with {:ok, parent} <- parent(module, graph) do
          {:ok,
           [
             {:vertex, reactor_vertex},
             {:edge, parent, reactor_vertex, :reactor},
             {:edge, module_vertex, reactor_vertex, :reactor}
           ]}
        end
      else
        {:ok, []}
      end
    end

    # Matched by struct name, so this compiles where Reactor is used without Ash.
    def introspect_vertex(%{__struct__: Action, action: action} = action_vertex, graph) do
      with reactor when reactor != nil <- Vertex.Reactor.run_by(action),
           true <- Config.should_process_module?(reactor) do
        case Clarity.Graph.get_vertex(graph, Util.id(Vertex.Reactor, [reactor])) do
          nil -> {:error, :unmet_dependencies}
          reactor_vertex -> {:ok, [{:edge, action_vertex, reactor_vertex, :reactor}]}
        end
      else
        _not_a_reactor -> {:ok, []}
      end
    end

    # A domain loses its edges when it's introspected again (any change to its
    # resources recompiles it), and its reactors aren't, so relink them here,
    # unless the reactor linked itself to the domain first.
    def introspect_vertex(%{__struct__: Domain, domain: domain} = domain_vertex, graph) do
      edges =
        for %Vertex.Reactor{reactor: reactor} = reactor_vertex <-
              Clarity.Graph.vertices(graph, {:==, :vertex_type, Vertex.Reactor}),
            domain(reactor, domains(reactor)) == domain,
            domain_vertex not in Clarity.Graph.in_neighbors(graph, reactor_vertex),
            do: {:edge, domain_vertex, reactor_vertex, :reactor}

      {:ok, edges}
    end

    # A reactor hangs off its domain, once that's in the graph, or else off
    # its application.
    @spec parent(module(), Clarity.Graph.t()) ::
            {:ok, Vertex.t() | nil} | {:error, :unmet_dependencies}
    defp parent(reactor, graph) do
      case domain(reactor, domains(reactor)) do
        nil ->
          app = Application.get_application(reactor)
          {:ok, Clarity.Graph.get_vertex(graph, Util.id(Vertex.Application, [app]))}

        domain ->
          case Clarity.Graph.get_vertex(graph, Util.id(Domain, [domain])) do
            nil -> {:error, :unmet_dependencies}
            domain_vertex -> {:ok, domain_vertex}
          end
      end
    end

    @doc false
    @spec domain(module(), [module()]) :: module() | nil
    def domain(reactor, domains) do
      Enum.find(domains, &runs?(&1, reactor)) ||
        Enum.find(domains, &String.starts_with?(inspect(reactor), inspect(&1) <> "."))
    end

    if Code.ensure_loaded?(Ash) do
      @spec domains(module()) :: [module()]
      defp domains(reactor), do: reactor |> Application.get_application() |> Ash.Info.domains()

      @spec runs?(module(), module()) :: boolean()
      defp runs?(domain, reactor) do
        domain
        |> Ash.Domain.Info.resources()
        |> Enum.flat_map(&Ash.Resource.Info.actions/1)
        |> Enum.any?(&(Vertex.Reactor.run_by(&1) == reactor))
      end
    else
      @spec domains(module()) :: [module()]
      defp domains(_reactor), do: []

      @spec runs?(module(), module()) :: boolean()
      defp runs?(_domain, _reactor), do: false
    end
  end
end
