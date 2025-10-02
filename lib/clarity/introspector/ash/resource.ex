case Code.ensure_loaded(Ash) do
  {:module, Ash} ->
    defmodule Clarity.Introspector.Ash.Resource do
      @moduledoc false

      @behaviour Clarity.Introspector

      alias Ash.Resource.Info
      alias Clarity.Graph
      alias Clarity.Vertex.Ash.Domain
      alias Clarity.Vertex.Ash.Resource
      alias Clarity.Vertex.Module

      @impl Clarity.Introspector
      def source_vertex_types, do: [Module]

      @impl Clarity.Introspector
      def introspect_vertex(%Module{module: module} = module_vertex, graph) do
        resource? =
          case module.module_info(:attributes)[:spark_is] do
            nil -> false
            attrs when is_list(attrs) -> Ash.Resource in attrs
          end

        if resource? do
          domain = Info.domain(module)

          with {:ok, domain_vertex} <- get_domain_vertex(graph, domain) do
            resource_vertex = %Resource{resource: module}

            {:ok,
             [
               {:vertex, resource_vertex},
               {:edge, domain_vertex, resource_vertex, :resource},
               {:edge, module_vertex, resource_vertex, :resource}
             ]}
          end
        else
          {:ok, []}
        end
      rescue
        UndefinedFunctionError -> {:ok, []}
      end

      @spec get_domain_vertex(Graph.t(), nil) :: {:ok, nil}
      @spec get_domain_vertex(Graph.t(), module()) ::
              {:ok, Domain.t()} | {:error, :unmet_dependencies}
      defp get_domain_vertex(graph, domain)
      defp get_domain_vertex(_graph, nil), do: {:ok, nil}

      defp get_domain_vertex(graph, domain) do
        graph
        |> Graph.vertices(type: Domain, field_equal: {:domain, domain})
        |> case do
          [%Domain{} = vertex] -> {:ok, vertex}
          [] -> {:error, :unmet_dependencies}
        end
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
