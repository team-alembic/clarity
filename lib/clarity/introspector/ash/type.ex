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

      @impl Clarity.Introspector
      def source_vertex_types, do: [Attribute, Aggregate, Calculation]

      @impl Clarity.Introspector
      def introspect_vertex(%Attribute{attribute: %{type: type}} = field_vertex, graph) do
        create_type_vertex_and_edges(type, field_vertex, graph)
      end

      def introspect_vertex(%Aggregate{aggregate: %{type: type}} = field_vertex, graph) do
        create_type_vertex_and_edges(type, field_vertex, graph)
      end

      def introspect_vertex(%Calculation{calculation: %{type: type}} = field_vertex, graph) do
        create_type_vertex_and_edges(type, field_vertex, graph)
      end

      def introspect_vertex(_vertex, _graph), do: []

      @spec create_type_vertex_and_edges(Ash.Type.t(), Vertex.t(), Clarity.Graph.t()) ::
              Clarity.Introspector.results()
      defp create_type_vertex_and_edges(type, field_vertex, graph) do
        simplified_type = simplify_type(type)
        type_vertex = %Type{type: simplified_type}
        app = Application.get_application(simplified_type)

        app_vertex =
          graph
          |> Clarity.Graph.vertices()
          |> Enum.find(&match?(%Vertex.Application{app: ^app}, &1))

        # Check if the type vertex already exists in the graph
        existing_type_vertex =
          graph
          |> Clarity.Graph.vertices()
          |> Enum.find(&match?(%Type{type: ^simplified_type}, &1))

        case existing_type_vertex do
          nil ->
            # Type vertex doesn't exist, create it with both edges
            [
              {:vertex, type_vertex},
              {:edge, app_vertex, type_vertex, :type},
              {:edge, field_vertex, type_vertex, :type}
              | Clarity.Introspector.moduledoc_content(simplified_type, type_vertex)
            ]

          existing_vertex ->
            # Type vertex exists, only create the field -> type edge
            [
              {:edge, field_vertex, existing_vertex, :type}
            ]
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
      def introspect_vertex(_vertex, _graph), do: []
    end
end
