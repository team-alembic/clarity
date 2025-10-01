case Code.ensure_loaded(Spark) do
  {:module, Spark} ->
    defmodule Clarity.Introspector.Spark.Extension do
      @moduledoc false

      @behaviour Clarity.Introspector

      alias Clarity.Vertex
      alias Clarity.Vertex.Module
      alias Clarity.Vertex.Spark.Extension

      @impl Clarity.Introspector
      def source_vertex_types, do: [Module]

      @impl Clarity.Introspector
      def introspect_vertex(%Module{module: module} = module_vertex, graph) do
        if Spark.implements_behaviour?(module, Spark.Dsl.Extension) do
          app = Application.get_application(module)

          app_vertex =
            graph
            |> Clarity.Graph.vertices()
            |> Enum.find(&match?(%Vertex.Application{app: ^app}, &1))

          extension_vertex = %Extension{extension: module}

          {:ok,
           [
             {:vertex, extension_vertex},
             {:edge, app_vertex, extension_vertex, :spark_extension},
             {:edge, module_vertex, extension_vertex, :spark_extension}
             | Clarity.Introspector.moduledoc_content(module, extension_vertex)
           ]}
        else
          {:ok, []}
        end
      end
    end

  _ ->
    defmodule Clarity.Introspector.Spark.Extension do
      @moduledoc false

      @behaviour Clarity.Introspector

      @impl Clarity.Introspector
      def source_vertex_types, do: []

      @impl Clarity.Introspector
      def introspect_vertex(_vertex, _graph), do: {:ok, []}
    end
end
