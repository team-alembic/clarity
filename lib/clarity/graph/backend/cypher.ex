defmodule Clarity.Graph.Backend.Cypher do
  @moduledoc """
  Shared Cypher query builder and vertex serializer for external graph backends.

  Translates Clarity's query DSL into Cypher WHERE clauses and provides
  serialization helpers for storing Elixir vertex structs in graph databases.

  Used by both `Clarity.Graph.Backend.Neo4j` and `Clarity.Graph.Backend.ArcadeDB`.
  """

  # Query DSL -> Cypher WHERE clause

  @doc false
  @spec query_to_cypher(Clarity.Graph.query(), String.t()) :: String.t()
  def query_to_cypher(query, var \\ "v") do
    case translate_query(query, var) do
      nil -> ""
      clause -> " WHERE #{clause}"
    end
  end

  @doc false
  @spec query_with_subgraph(Clarity.Graph.query(), String.t(), MapSet.t(String.t()) | nil) ::
          String.t()
  def query_with_subgraph(query, var, subgraph_ids) do
    query_clause = translate_query(query, var)
    subgraph_clause = subgraph_filter_clause(subgraph_ids, var)

    case {query_clause, subgraph_clause} do
      {nil, nil} -> ""
      {nil, subgraph} -> " WHERE #{subgraph}"
      {query_part, nil} -> " WHERE #{query_part}"
      {query_part, subgraph} -> " WHERE (#{query_part}) AND (#{subgraph})"
    end
  end

  @doc false
  @spec subgraph_where(MapSet.t(String.t()) | nil, String.t()) :: String.t()
  def subgraph_where(nil, _var), do: ""

  def subgraph_where(ids, var) do
    " WHERE " <> subgraph_filter_clause(ids, var)
  end

  @doc false
  @spec subgraph_where_multi(MapSet.t(String.t()) | nil, [String.t()]) :: String.t()
  def subgraph_where_multi(nil, _vars), do: ""

  def subgraph_where_multi(ids, vars) do
    id_list = cypher_list(MapSet.to_list(ids))
    clauses = Enum.map_join(vars, " AND ", fn var -> "#{var}.id IN #{id_list}" end)
    " WHERE #{clauses}"
  end

  @spec translate_query(Clarity.Graph.query(), String.t()) :: String.t() | nil
  defp translate_query(true, _var), do: nil
  defp translate_query(false, _var), do: "false"

  defp translate_query({:and, q1, q2}, var) do
    left = translate_query(q1, var)
    right = translate_query(q2, var)

    case {left, right} do
      {nil, nil} -> nil
      {nil, r} -> r
      {l, nil} -> l
      {l, r} -> "(#{l}) AND (#{r})"
    end
  end

  defp translate_query({:or, q1, q2}, var) do
    left = translate_query(q1, var)
    right = translate_query(q2, var)

    case {left, right} do
      {nil, nil} -> nil
      {nil, r} -> r
      {l, nil} -> l
      {l, r} -> "(#{l}) OR (#{r})"
    end
  end

  defp translate_query({:not, q}, var) do
    case translate_query(q, var) do
      nil -> nil
      inner -> "NOT (#{inner})"
    end
  end

  defp translate_query({:==, subject, value}, var) do
    "#{cypher_subject(subject, var)} = #{cypher_value(value)}"
  end

  defp translate_query({:!=, subject, value}, var) do
    "#{cypher_subject(subject, var)} <> #{cypher_value(value)}"
  end

  defp translate_query({:in, _field, []}, _var), do: "false"

  defp translate_query({:in, field, values}, var) when is_list(values) do
    "#{cypher_subject(field, var)} IN [#{Enum.map_join(values, ", ", &cypher_value/1)}]"
  end

  @spec cypher_subject(Clarity.Graph.query_subject(), String.t()) :: String.t()
  defp cypher_subject(:vertex_type, var), do: "#{var}.type"
  defp cypher_subject(:vertex_id, var), do: "#{var}.id"
  defp cypher_subject({:field, field}, var), do: "#{var}.prop_#{field}"

  @spec cypher_value(term()) :: String.t()
  defp cypher_value(value) when is_binary(value), do: "'#{escape_cypher_string(value)}'"
  defp cypher_value(value) when is_atom(value), do: "'#{escape_cypher_string(to_string(value))}'"
  defp cypher_value(value) when is_integer(value), do: Integer.to_string(value)
  defp cypher_value(value) when is_float(value), do: Float.to_string(value)
  defp cypher_value(true), do: "true"
  defp cypher_value(false), do: "false"
  defp cypher_value(value), do: "'#{escape_cypher_string(inspect(value))}'"

  @doc false
  @spec escape_cypher_string(String.t()) :: String.t()
  def escape_cypher_string(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("'", "\\'")
  end

  @doc false
  @spec cypher_list([String.t()]) :: String.t()
  def cypher_list(items) do
    "[#{Enum.map_join(items, ", ", &"'#{escape_cypher_string(&1)}'")}]"
  end

  @spec subgraph_filter_clause(MapSet.t(String.t()) | nil, String.t()) :: String.t() | nil
  defp subgraph_filter_clause(nil, _var), do: nil

  defp subgraph_filter_clause(ids, var) do
    "#{var}.id IN #{cypher_list(MapSet.to_list(ids))}"
  end

  # Vertex serialization

  @doc false
  @spec serialize_vertex(String.t(), module(), struct()) :: map()
  def serialize_vertex(vertex_id, vertex_type, vertex_struct) do
    base = %{
      "id" => vertex_id,
      "type" => to_string(vertex_type),
      "data" => Base.encode64(:erlang.term_to_binary(vertex_struct))
    }

    promoted =
      vertex_struct
      |> Map.from_struct()
      |> Enum.reduce(%{}, fn {field, value}, acc ->
        if promotable_value?(value) do
          Map.put(acc, "prop_#{field}", serialize_field_value(value))
        else
          acc
        end
      end)

    Map.merge(base, promoted)
  end

  @spec promotable_value?(term()) :: boolean()
  defp promotable_value?(nil), do: false
  defp promotable_value?(value) when is_atom(value), do: true
  defp promotable_value?(value) when is_binary(value), do: true
  defp promotable_value?(value) when is_number(value), do: true
  defp promotable_value?(_), do: false

  @doc false
  @spec deserialize_vertex(map()) :: struct()
  def deserialize_vertex(%{"data" => data}) do
    data |> Base.decode64!() |> :erlang.binary_to_term()
  end

  @doc false
  @spec serialize_field_value(term()) :: String.t()
  def serialize_field_value(value) when is_atom(value), do: to_string(value)
  def serialize_field_value(value) when is_binary(value), do: value
  def serialize_field_value(value), do: inspect(value)

  # Cypher statement builders

  @doc false
  @spec merge_vertex_cypher(map()) :: {String.t(), map()}
  def merge_vertex_cypher(props) do
    {"MERGE (v:Vertex {id: $id}) SET v = $props", %{"id" => props["id"], "props" => props}}
  end

  @doc false
  @spec merge_edge_cypher(String.t(), String.t(), term(), String.t()) :: {String.t(), map()}
  def merge_edge_cypher(from_id, to_id, label, rel_type \\ "EDGE") do
    cypher = """
    MATCH (a:Vertex {id: $from_id}), (b:Vertex {id: $to_id})
    MERGE (a)-[r:#{rel_type} {label: $label}]->(b)
    """

    params = %{"from_id" => from_id, "to_id" => to_id, "label" => serialize_field_value(label)}
    {cypher, params}
  end

  @doc false
  @spec delete_vertex_cypher(String.t()) :: {String.t(), map()}
  def delete_vertex_cypher(vertex_id) do
    {"MATCH (v:Vertex {id: $id}) DETACH DELETE v", %{"id" => vertex_id}}
  end

  @doc false
  @spec shortest_path_cypher(String.t(), String.t(), String.t()) :: {String.t(), map()}
  def shortest_path_cypher(from_id, to_id, rel_type \\ "EDGE") do
    cypher = """
    MATCH p = shortestPath((a:Vertex {id: $from_id})-[:#{rel_type}*]->(b:Vertex {id: $to_id}))
    RETURN [n IN nodes(p) | n {.*}] AS path
    """

    {cypher, %{"from_id" => from_id, "to_id" => to_id}}
  end

  @doc false
  @spec vertices_within_steps_cypher(String.t(), non_neg_integer(), non_neg_integer()) ::
          {String.t(), map()}
  def vertices_within_steps_cypher(vertex_id, max_out, max_in) do
    cypher = """
    MATCH (center:Vertex {id: $id})
    OPTIONAL MATCH (center)-[:EDGE*0..#{max_out}]->(out_v:Vertex)
    OPTIONAL MATCH (center)<-[:EDGE*0..#{max_in}]-(in_v:Vertex)
    WITH collect(DISTINCT out_v.id) + collect(DISTINCT in_v.id) AS ids
    UNWIND ids AS vid
    RETURN DISTINCT vid
    """

    {cypher, %{"id" => vertex_id}}
  end
end
