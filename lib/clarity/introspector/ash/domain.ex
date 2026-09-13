case Code.ensure_loaded(Ash) do
  {:module, Ash} ->
    defmodule Clarity.Introspector.Ash.Domain do
      @moduledoc false

      @behaviour Clarity.Introspector

      alias Ash.Domain.Info
      alias Clarity.Graph
      alias Clarity.Vertex
      alias Clarity.Vertex.Ash.Domain
      alias Clarity.Vertex.Ash.Resource
      alias Clarity.Vertex.Module
      alias Clarity.Vertex.Util

      @impl Clarity.Introspector
      def source_vertex_types, do: [Module]

      @impl Clarity.Introspector
      def introspect_vertex(%Module{module: module} = module_vertex, graph) do
        if Spark.implements_behaviour?(module, Ash.Domain) do
          app = Application.get_application(module)

          app_vertex = Graph.get_vertex(graph, Util.id(Vertex.Application, [app]))

          domain_vertex = %Domain{domain: module}

          # Re-link resource vertices that already exist in the graph.
          #
          # When a domain module is recompiled (every resource change triggers this,
          # because `resources do ... end` is a compile-time dependency) the incremental
          # introspection purges the domain vertex and, with it, every edge it had.
          # Resources whose modules did not change are never re-introspected, so
          # without this they stay in the graph but disappear from the domain in the
          # navigation tree.
          resource_edges =
            module
            |> Info.resources()
            |> Enum.map(&Graph.get_vertex(graph, Util.id(Resource, [&1])))
            |> Enum.reject(&is_nil/1)
            |> Enum.map(&{:edge, domain_vertex, &1, :resource})

          {:ok,
           [
             {:vertex, domain_vertex},
             {:edge, app_vertex, domain_vertex, :domain},
             {:edge, module_vertex, domain_vertex, :module}
             | resource_edges
           ]}
        else
          {:ok, []}
        end
      end
    end

  _ ->
    defmodule Clarity.Introspector.Ash.Domain do
      @moduledoc false

      @behaviour Clarity.Introspector

      @impl Clarity.Introspector
      def source_vertex_types, do: []

      @impl Clarity.Introspector
      def introspect_vertex(_vertex, _graph), do: {:ok, []}
    end
end
