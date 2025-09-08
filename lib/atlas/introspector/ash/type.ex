case Code.ensure_loaded(Ash) do
  {:module, Ash} ->
    defmodule Atlas.Introspector.Ash.Type do
      @moduledoc false

      @behaviour Atlas.Introspector

      alias Atlas.Vertex
      alias Atlas.Vertex.Ash.Aggregate
      alias Atlas.Vertex.Ash.Attribute
      alias Atlas.Vertex.Ash.Calculation

      @impl Atlas.Introspector
      def introspect(graph) do
        app_vertices =
          graph
          |> :digraph.vertices()
          |> Enum.filter(&match?(%Vertex.Application{}, &1))
          |> Map.new(&{&1.app, &1})

        types =
          graph
          |> :digraph.vertices()
          |> Enum.flat_map(fn
            %Attribute{attribute: %{type: type}} -> [type]
            %Aggregate{aggregate: %{type: type}} -> [type]
            %Calculation{calculation: %{type: type}} -> [type]
            _ -> []
          end)
          |> Enum.map(&simplify_type/1)
          |> Enum.reject(&is_nil/1)
          |> Enum.uniq()
          |> Map.new(fn type ->
            type_vertex = %Vertex.Ash.Type{type: type}
            type_vertex = :digraph.add_vertex(graph, type_vertex, Vertex.unique_id(type_vertex))

            app = Application.get_application(type)
            app_vertex = Map.fetch!(app_vertices, app)

            :digraph.add_edge(graph, app_vertex, type_vertex, :type)

            Atlas.Introspector.attach_moduledoc_content(type, graph, type_vertex)

            {type, type_vertex}
          end)

        graph
        |> :digraph.vertices()
        |> Enum.flat_map(fn
          %Attribute{} = vertex -> [{vertex, vertex.attribute.type}]
          %Aggregate{} = vertex -> [{vertex, vertex.aggregate.type}]
          %Calculation{} = vertex -> [{vertex, vertex.calculation.type}]
          _ -> []
        end)
        |> Enum.each(fn {vertex, type} ->
          case Map.fetch(types, simplify_type(type)) do
            :error -> :ok
            {:ok, type_vertex} -> :digraph.add_edge(graph, vertex, type_vertex, :type)
          end
        end)

        graph
      end

      @spec simplify_type(type :: Ash.Type.t()) :: Ash.Type.t()
      defp simplify_type({:array, type}), do: simplify_type(type)
      defp simplify_type(type), do: type
    end

  _ ->
    defmodule Atlas.Introspector.Ash.Type do
      @moduledoc false

      @behaviour Atlas.Introspector

      @impl Atlas.Introspector
      def introspect(graph), do: graph
    end
end
