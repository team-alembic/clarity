case Code.ensure_loaded(Spark) do
  {:module, Spark} ->
    defmodule Clarity.Introspector.Spark.Dsl do
      @moduledoc false

      @behaviour Clarity.Introspector

      alias Clarity.Vertex
      alias Clarity.Vertex.Module
      alias Clarity.Vertex.Spark.Dsl
      alias Clarity.Vertex.Spark.Extension
      alias Clarity.Vertex.Util

      @impl Clarity.Introspector
      def source_vertex_types, do: [Module, Dsl]

      @impl Clarity.Introspector
      def introspect_vertex(%Module{module: module} = module_vertex, graph) do
        if spark_dsl?(module) do
          app = Clarity.Config.application_of(module)

          app_vertex = Clarity.Graph.get_vertex(graph, Util.id(Vertex.Application, [app]))

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
        for extension <- needed_extensions,
            vertex = Clarity.Graph.get_vertex(graph, Util.id(Extension, [extension])),
            into: %{},
            do: {extension, vertex}
      end

      @spec create_extension_edges(Dsl.t(), [module()], %{module() => Extension.t()}) ::
              Clarity.Introspector.result()
      defp create_extension_edges(_dsl_vertex, [], _lookup), do: {:ok, []}

      defp create_extension_edges(dsl_vertex, extensions, lookup) do
        case Enum.reject(extensions, &Map.has_key?(lookup, &1)) do
          [] ->
            edges =
              for extension <- Enum.reverse(extensions),
                  do: {:edge, dsl_vertex, Map.fetch!(lookup, extension), :uses_extension}

            {:ok, edges}

          missing ->
            {:error, {:unmet_dependencies, missing}}
        end
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
