defmodule AshAtlas.Introspector.Type do
  @moduledoc false

  @behaviour AshAtlas.Introspector

  alias AshAtlas.Vertex

  @impl AshAtlas.Introspector
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
        %Vertex.Attribute{attribute: %{type: type}} -> [type]
        %Vertex.Aggregate{aggregate: %{type: type}} -> [type]
        %Vertex.Calculation{calculation: %{type: type}} -> [type]
        _ -> []
      end)
      |> Enum.map(&simplify_type/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Map.new(fn type ->
        type_vertex = %Vertex.Type{type: type}
        type_vertex = :digraph.add_vertex(graph, type_vertex, Vertex.unique_id(type_vertex))

        app = Application.get_application(type)
        app_vertex = Map.fetch!(app_vertices, app)

        :digraph.add_edge(graph, app_vertex, type_vertex, :type)

        {type, type_vertex}
      end)

    graph
    |> :digraph.vertices()
    |> Enum.flat_map(fn
      %Vertex.Attribute{} = vertex -> [{vertex, vertex.attribute.type}]
      %Vertex.Aggregate{} = vertex -> [{vertex, vertex.aggregate.type}]
      %Vertex.Calculation{} = vertex -> [{vertex, vertex.calculation.type}]
      _ -> []
    end)
    |> Enum.map(fn {vertex, type} ->
      case Map.fetch(types, simplify_type(type)) do
        :error -> :ok
        {:ok, type_vertex} -> :digraph.add_edge(graph, vertex, type_vertex, :type)
      end
    end)

    graph
  end

  defp simplify_type({:array, type}), do: simplify_type(type)
  defp simplify_type(type), do: type
end
