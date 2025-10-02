case Code.ensure_loaded(Ash) do
  {:module, Ash} ->
    defmodule Clarity.Introspector.Ash.Type do
      @moduledoc false

      @behaviour Clarity.Introspector

      alias Clarity.Vertex
      alias Clarity.Vertex.Ash.Aggregate
      alias Clarity.Vertex.Ash.Attribute
      alias Clarity.Vertex.Ash.Calculation
      alias Clarity.Vertex.Ash.Type
      alias Clarity.Vertex.Module

      @impl Clarity.Introspector
      def source_vertex_types, do: [Module, Attribute, Aggregate, Calculation]

      @impl Clarity.Introspector
      def introspect_vertex(%Module{module: module} = module_vertex, graph) do
        if Spark.implements_behaviour?(module, Ash.Type) do
          app = Application.get_application(module)

          app_vertex =
            graph
            |> Clarity.Graph.vertices(type: Vertex.Application, field_equal: {:app, app})
            |> List.first()

          type_vertex = %Type{type: module}

          {:ok,
           [
             {:vertex, type_vertex},
             {:edge, app_vertex, type_vertex, :type},
             {:edge, module_vertex, type_vertex, :type}
             | Clarity.Introspector.moduledoc_content(module, type_vertex)
           ]}
        else
          {:ok, []}
        end
      end

      def introspect_vertex(%Attribute{attribute: %{type: type}} = field_vertex, graph) do
        create_type_edge(type, field_vertex, graph)
      end

      def introspect_vertex(%Aggregate{aggregate: %{type: type}} = field_vertex, graph) do
        create_type_edge(type, field_vertex, graph)
      end

      def introspect_vertex(%Calculation{calculation: %{type: type}} = field_vertex, graph) do
        create_type_edge(type, field_vertex, graph)
      end

      @spec create_type_edge(Ash.Type.t() | nil, Vertex.t(), Clarity.Graph.t()) ::
              Clarity.Introspector.result()
      defp create_type_edge(type, field_vertex, graph)
      defp create_type_edge(nil, _field_vertex, _graph), do: {:ok, []}

      defp create_type_edge(type, field_vertex, graph) do
        simplified_type = simplify_type(type)
        Code.ensure_loaded(simplified_type)

        # Check if the type vertex already exists in the graph
        graph
        |> Clarity.Graph.vertices(type: Type, field_equal: {:type, simplified_type})
        |> case do
          [] -> {:error, :unmet_dependencies}
          [vertex] -> {:ok, [{:edge, field_vertex, vertex, :type}]}
        end
      end

      @spec simplify_type(type :: Ash.Type.t()) :: Ash.Type.t()
      defp simplify_type({:array, type}), do: simplify_type(type)
      defp simplify_type(type), do: type
    end

  _ ->
    defmodule Clarity.Introspector.Ash.Type do
      @moduledoc false

      @behaviour Clarity.Introspector

      @impl Clarity.Introspector
      def source_vertex_types, do: []

      @impl Clarity.Introspector
      def introspect_vertex(_vertex, _graph), do: {:ok, []}
    end
end
