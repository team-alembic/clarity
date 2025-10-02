case Code.ensure_loaded(Spark) do
  {:module, Spark} ->
    defmodule Clarity.Introspector.Spark.Dsl do
      @moduledoc false

      @behaviour Clarity.Introspector

      alias Clarity.Vertex
      alias Clarity.Vertex.Module
      alias Clarity.Vertex.Spark.Dsl
      alias Clarity.Vertex.Spark.Extension

      @impl Clarity.Introspector
      def source_vertex_types, do: [Module, Dsl]

      @impl Clarity.Introspector
      def introspect_vertex(%Module{module: module} = module_vertex, graph) do
        if spark_dsl?(module) do
          app = Application.get_application(module)

          app_vertex =
            graph
            |> Clarity.Graph.vertices(type: Vertex.Application, field_equal: {:app, app})
            |> List.first()

          dsl_vertex = %Dsl{dsl: module}

          {:ok,
           [
             {:vertex, dsl_vertex},
             {:edge, app_vertex, dsl_vertex, :spark_dsl},
             {:edge, module_vertex, dsl_vertex, :spark_dsl}
           ]}
        else
          {:ok, []}
        end
      end

      @impl Clarity.Introspector
      def introspect_vertex(%Dsl{dsl: dsl_module} = dsl_vertex, graph) do
        extensions = get_extensions(dsl_module)
        extension_lookup = build_extension_lookup(graph, extensions)

        create_extension_edges(dsl_vertex, extensions, extension_lookup)
      end

      @spec spark_dsl?(module()) :: boolean()
      defp spark_dsl?(module) do
        module.module_info(:attributes)[:spark_dsl] == [true]
      end

      @spec get_extensions(module()) :: [module()]
      defp get_extensions(dsl_module) do
        case dsl_module.module_info(:attributes)[:spark_default_extensions] do
          nil -> []
          extensions when is_list(extensions) -> extensions
        end
      end

      @spec build_extension_lookup(Clarity.Graph.t(), [module()]) :: %{
              module() => Extension.t()
            }
      defp build_extension_lookup(graph, needed_extensions) do
        graph
        |> Clarity.Graph.vertices(type: Extension, field_in: {:extension, needed_extensions})
        |> Map.new(&{&1.extension, &1})
      end

      @spec create_extension_edges(Dsl.t(), [module()], %{module() => Extension.t()}) ::
              Clarity.Introspector.result()
      defp create_extension_edges(_dsl_vertex, [], _lookup), do: {:ok, []}

      defp create_extension_edges(dsl_vertex, extensions, lookup) do
        Enum.reduce_while(extensions, {:ok, []}, fn extension, {:ok, edges} ->
          case Map.fetch(lookup, extension) do
            {:ok, extension_vertex} ->
              {:cont, {:ok, [{:edge, dsl_vertex, extension_vertex, :uses_extension} | edges]}}

            :error ->
              {:halt, {:error, :unmet_dependencies}}
          end
        end)
      end
    end

  _ ->
    defmodule Clarity.Introspector.Spark.Dsl do
      @moduledoc false

      @behaviour Clarity.Introspector

      @impl Clarity.Introspector
      def source_vertex_types, do: []

      @impl Clarity.Introspector
      def introspect_vertex(_vertex, _graph), do: {:ok, []}
    end
end
