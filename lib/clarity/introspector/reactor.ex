with {:module, Reactor} <- Code.ensure_loaded(Reactor) do
  defmodule Clarity.Introspector.Reactor do
    @moduledoc false

    @behaviour Clarity.Introspector

    alias Clarity.Config
    alias Clarity.Vertex
    alias Clarity.Vertex.Ash.Action
    alias Clarity.Vertex.Module
    alias Clarity.Vertex.Util

    @impl Clarity.Introspector
    def source_vertex_types, do: [Module, Action]

    @impl Clarity.Introspector
    def introspect_vertex(%Module{module: module} = module_vertex, graph) do
      if Vertex.Reactor.reactor?(module) do
        app = Application.get_application(module)
        app_vertex = Clarity.Graph.get_vertex(graph, Util.id(Vertex.Application, [app]))
        reactor_vertex = %Vertex.Reactor{reactor: module}

        {:ok,
         [
           {:vertex, reactor_vertex},
           {:edge, app_vertex, reactor_vertex, :reactor},
           {:edge, module_vertex, reactor_vertex, :reactor}
         ]}
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
  end
end
