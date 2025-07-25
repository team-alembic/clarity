defmodule AshAtlas.Resolver.Type do
  @behaviour AshAtlas.Resolver

  alias AshAtlas.Tree.Node

  @impl AshAtlas.Resolver
  def resolve(graph) do
    app_vertices =
      graph
      |> :digraph.vertices()
      |> Enum.filter(&match?(%Node.Application{}, &1))
      |> Map.new(&{&1.app, &1})

    types =
      graph
      |> :digraph.vertices()
      |> Enum.flat_map(fn
        %Node.Attribute{attribute: %{type: type}} -> [type]
        %Node.Aggregate{aggregate: %{type: type}} -> [type]
        %Node.Calculation{calculation: %{type: type}} -> [type]
        _ -> []
      end)
      |> Enum.map(&simplify_type/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Map.new(fn type ->
        type_node = %Node.Type{type: type}
        type_vertex = :digraph.add_vertex(graph, type_node, Node.unique_id(type_node))

        app = Application.get_application(type)
        app_vertex = Map.fetch!(app_vertices, app)

        :digraph.add_edge(graph, app_vertex, type_vertex, :type)

        {type, type_vertex}
      end)

    graph
    |> :digraph.vertices()
    |> Enum.flat_map(fn
      %Node.Attribute{} = vertex -> [{vertex, vertex.attribute.type}]
      %Node.Aggregate{} = vertex -> [{vertex, vertex.aggregate.type}]
      %Node.Calculation{} = vertex -> [{vertex, vertex.calculation.type}]
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

  @impl AshAtlas.Resolver
  def post_process(graph) do
    # No post-processing needed for the domain resolver
    graph
  end

  defp simplify_type({:array, type}), do: simplify_type(type)
  defp simplify_type(type), do: type
end
