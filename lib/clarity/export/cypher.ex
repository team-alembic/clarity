defmodule Clarity.Export.Cypher do
  @moduledoc """
  Shared serialization helpers for graph database exports.
  """

  alias Clarity.Vertex

  @neo4j_max_integer 9_223_372_036_854_775_807
  @neo4j_min_integer -9_223_372_036_854_775_808

  @doc """
  Serializes a Clarity vertex into exportable properties.
  """
  @spec serialize_vertex(Vertex.t()) :: map()
  def serialize_vertex(vertex) do
    base = %{
      "id" => Vertex.id(vertex),
      "type" => to_string(vertex.__struct__),
      "type_label" => Vertex.type_label(vertex),
      "name" => Vertex.name(vertex),
      "data" => Base.encode64(:erlang.term_to_binary(vertex))
    }

    promoted =
      vertex
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

  @doc """
  Serializes an edge returned by `Clarity.Graph.edge/2`.
  """
  @spec serialize_edge({term(), Vertex.t(), Vertex.t(), term()}) :: map()
  def serialize_edge({_edge_id, from_vertex, to_vertex, label}) do
    %{
      "from_id" => Vertex.id(from_vertex),
      "to_id" => Vertex.id(to_vertex),
      "label" => serialize_field_value(label)
    }
  end

  @doc false
  @spec escape_cypher_string(String.t()) :: String.t()
  def escape_cypher_string(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("'", "\\'")
  end

  @doc false
  @spec serialize_field_value(term()) :: term()
  def serialize_field_value(value) when is_atom(value), do: to_string(value)
  def serialize_field_value(value) when is_binary(value), do: value

  def serialize_field_value(value)
      when is_integer(value) and value in @neo4j_min_integer..@neo4j_max_integer,
      do: value

  def serialize_field_value(value) when is_integer(value), do: Integer.to_string(value)
  def serialize_field_value(value) when is_float(value), do: value
  def serialize_field_value(value), do: inspect(value)

  @spec promotable_value?(term()) :: boolean()
  defp promotable_value?(nil), do: false
  defp promotable_value?(value) when is_atom(value), do: true
  defp promotable_value?(value) when is_binary(value), do: true
  defp promotable_value?(value) when is_number(value), do: true
  defp promotable_value?(_), do: false
end
