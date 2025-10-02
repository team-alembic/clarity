case Code.ensure_loaded(Spark) do
  {:module, Spark} ->
    defmodule Clarity.Introspector.Spark.Section do
      @moduledoc false

      @behaviour Clarity.Introspector

      alias Clarity.Vertex.Module
      alias Clarity.Vertex.Spark.Dsl
      alias Clarity.Vertex.Spark.Section, as: SectionVertex

      @impl Clarity.Introspector
      def source_vertex_types, do: [Module]

      @impl Clarity.Introspector
      def introspect_vertex(%Module{module: module} = module_vertex, graph) do
        case get_dsl_base(module) do
          nil ->
            {:ok, []}

          dsl_base ->
            case find_dsl_vertex(graph, dsl_base) do
              nil ->
                {:error, :unmet_dependencies}

              dsl_vertex ->
                config = module.spark_dsl_config()
                section_paths = get_section_paths(config)

                section_entries =
                  create_section_entries(module, section_paths, module_vertex, dsl_vertex)

                {:ok,
                 [
                   {:edge, module_vertex, dsl_vertex, :uses_dsl}
                   | section_entries
                 ]}
            end
        end
      end

      @spec get_dsl_base(module()) :: module() | nil
      defp get_dsl_base(module) do
        # spark_is contains the DSL base (e.g., [Ash.Domain])
        case module.module_info(:attributes)[:spark_is] do
          [dsl_base | _] -> dsl_base
          _ -> nil
        end
      end

      @spec find_dsl_vertex(Clarity.Graph.t(), module()) :: Dsl.t() | nil
      defp find_dsl_vertex(graph, dsl_base) do
        graph
        |> Clarity.Graph.vertices(type: Dsl, field_equal: {:dsl, dsl_base})
        |> List.first()
      end

      @spec get_section_paths(map()) :: [[atom()]]
      defp get_section_paths(config) do
        config
        |> Map.keys()
        |> Enum.filter(&is_list/1)
      end

      @spec create_section_entries(module(), [[atom()]], Module.t(), Dsl.t()) :: [
              Clarity.Introspector.entry()
            ]
      defp create_section_entries(module, section_paths, module_vertex, dsl_vertex) do
        Enum.flat_map(section_paths, fn path ->
          section_vertex = %SectionVertex{module: module, path: path}

          [
            {:vertex, section_vertex},
            {:edge, module_vertex, section_vertex, :section},
            {:edge, section_vertex, dsl_vertex, :section_of}
          ]
        end)
      end
    end

  _ ->
    defmodule Clarity.Introspector.Spark.Section do
      @moduledoc false

      @behaviour Clarity.Introspector

      @impl Clarity.Introspector
      def source_vertex_types, do: []

      @impl Clarity.Introspector
      def introspect_vertex(_vertex, _graph), do: {:ok, []}
    end
end
