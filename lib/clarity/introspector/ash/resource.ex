case Code.ensure_loaded(Ash) do
  {:module, Ash} ->
    defmodule Clarity.Introspector.Ash.Resource do
      @moduledoc false

      @behaviour Clarity.Introspector

      alias Ash.Resource.Info
      alias Clarity.Vertex.Ash.Resource
      alias Clarity.Vertex.Module

      @impl Clarity.Introspector
      def source_vertex_types, do: [Module]

      @impl Clarity.Introspector
      def introspect_vertex(%Module{module: module} = module_vertex, graph) do
        # TODO: Remove Internal Spark API. Not using Spark.extensions/1 because
        # it hangs for some modules.
        resource? =
          case module.module_info(:attributes)[:spark_is] do
            nil -> false
            attrs when is_list(attrs) -> Ash.Resource in attrs
          end

        if resource? do
          domain = Info.domain(module)

          graph
          |> Clarity.Graph.vertices()
          |> Enum.find(&match?(%Clarity.Vertex.Ash.Domain{domain: ^domain}, &1))
          |> case do
            nil ->
              {:error, :unmet_dependencies}

            domain_vertex ->
              resource_vertex = %Resource{resource: module}

              {:ok,
               [
                 {:vertex, resource_vertex},
                 {:edge, domain_vertex, resource_vertex, :resource},
                 {:edge, module_vertex, resource_vertex, :resource}
                 | Clarity.Introspector.moduledoc_content(module, resource_vertex)
               ]}
          end
        else
          {:ok, []}
        end
      rescue
        # Happens if module is not loaded
        UndefinedFunctionError -> {:ok, []}
      end
    end

  _ ->
    defmodule Clarity.Introspector.Ash.Resource do
      @moduledoc false

      @behaviour Clarity.Introspector

      @impl Clarity.Introspector
      def source_vertex_types, do: []

      @impl Clarity.Introspector
      def introspect_vertex(_vertex, _graph), do: {:ok, []}
    end
end
