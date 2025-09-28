case Code.ensure_loaded(Ash) do
  {:module, Ash} ->
    defmodule Clarity.Introspector.Ash.Domain do
      @moduledoc false

      @behaviour Clarity.Introspector

      alias Clarity.Vertex
      alias Clarity.Vertex.Ash.Domain
      alias Clarity.Vertex.Module

      @impl Clarity.Introspector
      def source_vertex_types, do: [Module]

      @impl Clarity.Introspector
      def introspect_vertex(%Module{module: module} = module_vertex, graph) do
        if Spark.implements_behaviour?(module, Ash.Domain) do
          app = Application.get_application(module)

          app_vertex =
            graph
            |> Clarity.Graph.vertices()
            |> Enum.find(&match?(%Vertex.Application{app: ^app}, &1))

          domain_vertex = %Domain{domain: module}

          {:ok,
           [
             {:vertex, domain_vertex},
             {:edge, app_vertex, domain_vertex, :domain},
             {:edge, module_vertex, domain_vertex, :module}
             | Clarity.Introspector.moduledoc_content(module, domain_vertex)
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
