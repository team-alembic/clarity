if Code.ensure_loaded?(Reactor) do
  defmodule Clarity.Introspector.Reactor.Reactor do
    @moduledoc false
    @behaviour Clarity.Introspector

    alias Clarity.Vertex

    @impl true
    def dependencies, do: [Clarity.Introspector.Application]

    @impl true
    def introspect(graph) do
      for %Vertex.Application{app: app} = app_vertex <- :digraph.vertices(graph),
          module <- reactors(app) do
        reactor = module.reactor()

        reactor_vertex =
          :digraph.add_vertex(graph, reactor, Vertex.unique_id(reactor))

        :digraph.add_edge(graph, app_vertex, reactor_vertex, :reactor)

        Clarity.Introspector.attach_moduledoc_content(module, graph, reactor_vertex)
      end

      graph
    end

    defp reactors(app) do
      app
      |> Application.spec(:modules)
      |> Stream.filter(&Code.ensure_loaded?/1)
      |> Enum.filter(&(Reactor in (&1.module_info(:attributes)[:spark_is] || [])))
    end
  end
else
  defmodule Clarity.Introspector.Reactor.Reactor do
    @moduledoc false
    @behaviour Clarity.Introspector

    @impl true
    def dependencies, do: [Clarity.Introspector.Application]

    @impl true
    def introspect(graph), do: graph
  end
end
