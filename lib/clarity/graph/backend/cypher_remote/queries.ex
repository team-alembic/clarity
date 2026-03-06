defmodule Clarity.Graph.Backend.CypherRemote.Queries do
  @moduledoc false

  alias Clarity.Graph.Backend.Cypher
  alias Clarity.Graph.Backend.WriteBuffer

  @spec get_vertex(struct(), String.t(), module()) :: struct() | nil
  def get_vertex(state, vertex_id, adapter) do
    state = flush(state, adapter)

    case adapter.run_query(state, "MATCH (v:Vertex {id: $id}) RETURN v {.*}", %{"id" => vertex_id}) do
      [[props]] -> Cypher.deserialize_vertex(props)
      [] -> nil
    end
  end

  @spec vertex_count(struct(), module()) :: non_neg_integer()
  def vertex_count(state, adapter) do
    state = flush(state, adapter)

    case adapter.run_query(
           state,
           "MATCH (v:Vertex)" <>
             Cypher.subgraph_where(state.subgraph_ids, "v") <> " RETURN count(v) AS c",
           %{}
         ) do
      [[count]] -> count
      [] -> 0
    end
  end

  @spec out_neighbors(struct(), String.t(), module()) :: [struct()]
  def out_neighbors(state, vertex_id, adapter) do
    state = flush(state, adapter)

    state
    |> adapter.run_query(
      "MATCH (a:Vertex {id: $id})-[:EDGE]->(b:Vertex)" <>
        Cypher.subgraph_where(state.subgraph_ids, "b") <> " RETURN b {.*}",
      %{"id" => vertex_id}
    )
    |> Enum.map(fn [props] -> Cypher.deserialize_vertex(props) end)
  end

  @spec in_neighbors(struct(), String.t(), module()) :: [struct()]
  def in_neighbors(state, vertex_id, adapter) do
    state = flush(state, adapter)

    state
    |> adapter.run_query(
      "MATCH (a:Vertex)-[:EDGE]->(b:Vertex {id: $id})" <>
        Cypher.subgraph_where(state.subgraph_ids, "a") <> " RETURN a {.*}",
      %{"id" => vertex_id}
    )
    |> Enum.map(fn [props] -> Cypher.deserialize_vertex(props) end)
  end

  @spec out_edges(struct(), String.t(), module()) :: [term()]
  def out_edges(state, vertex_id, adapter) do
    state = flush(state, adapter)

    state
    |> adapter.run_query(
      "MATCH (a:Vertex {id: $id})-[r:EDGE]->(b:Vertex) RETURN id(r)",
      %{"id" => vertex_id}
    )
    |> Enum.map(fn [id] -> id end)
  end

  @spec in_edges(struct(), String.t(), module()) :: [term()]
  def in_edges(state, vertex_id, adapter) do
    state = flush(state, adapter)

    state
    |> adapter.run_query(
      "MATCH (a:Vertex)-[r:EDGE]->(b:Vertex {id: $id}) RETURN id(r)",
      %{"id" => vertex_id}
    )
    |> Enum.map(fn [id] -> id end)
  end

  @spec edges(struct(), module()) :: [term()]
  def edges(state, adapter) do
    state = flush(state, adapter)

    state
    |> adapter.run_query(
      "MATCH (a:Vertex)-[r:EDGE]->(b:Vertex)" <>
        Cypher.subgraph_where_multi(state.subgraph_ids, ["a", "b"]) <> " RETURN id(r)",
      %{}
    )
    |> Enum.map(fn [id] -> id end)
  end

  @spec edge(struct(), term(), module()) ::
          {term(), struct() | nil, struct() | nil, term()} | false
  def edge(state, edge_id, adapter) do
    state = flush(state, adapter)

    case adapter.run_query(
           state,
           "MATCH (a:Vertex)-[r:EDGE]->(b:Vertex) WHERE id(r) = $eid RETURN id(r), a {.*}, b {.*}, r.label",
           %{"eid" => edge_id}
         ) do
      [[eid, from_props, to_props, label]] ->
        {eid, Cypher.deserialize_vertex(from_props), Cypher.deserialize_vertex(to_props), label}

      [] ->
        false
    end
  end

  @spec in_degree(struct(), String.t(), module()) :: non_neg_integer()
  def in_degree(state, vertex_id, adapter) do
    state = flush(state, adapter)

    case adapter.run_query(
           state,
           "MATCH (a:Vertex)-[:EDGE]->(b:Vertex {id: $id}) RETURN count(a)",
           %{"id" => vertex_id}
         ) do
      [[count]] -> count
      [] -> 0
    end
  end

  @spec in_degree(struct(), String.t(), term(), module()) :: non_neg_integer()
  def in_degree(state, vertex_id, label, adapter) do
    state = flush(state, adapter)

    case adapter.run_query(
           state,
           "MATCH (a:Vertex)-[r:EDGE {label: $label}]->(b:Vertex {id: $id}) RETURN count(a)",
           %{"id" => vertex_id, "label" => Cypher.serialize_field_value(label)}
         ) do
      [[count]] -> count
      [] -> 0
    end
  end

  @spec out_degree(struct(), String.t(), module()) :: non_neg_integer()
  def out_degree(state, vertex_id, adapter) do
    state = flush(state, adapter)

    case adapter.run_query(
           state,
           "MATCH (a:Vertex {id: $id})-[:EDGE]->(b:Vertex) RETURN count(b)",
           %{"id" => vertex_id}
         ) do
      [[count]] -> count
      [] -> 0
    end
  end

  @spec out_degree(struct(), String.t(), term(), module()) :: non_neg_integer()
  def out_degree(state, vertex_id, label, adapter) do
    state = flush(state, adapter)

    case adapter.run_query(
           state,
           "MATCH (a:Vertex {id: $id})-[r:EDGE {label: $label}]->(b:Vertex) RETURN count(b)",
           %{"id" => vertex_id, "label" => Cypher.serialize_field_value(label)}
         ) do
      [[count]] -> count
      [] -> 0
    end
  end

  @spec vertices(struct(), Clarity.Graph.query(), module()) :: [struct()]
  def vertices(state, query, adapter) do
    state = flush(state, adapter)

    cypher =
      "MATCH (v:Vertex)" <>
        Cypher.query_with_subgraph(query, "v", state.subgraph_ids) <> " RETURN v {.*}"

    state
    |> adapter.run_query(cypher, %{})
    |> Enum.map(fn [props] -> Cypher.deserialize_vertex(props) end)
  end

  @spec vertex_ids(struct(), Clarity.Graph.query(), module()) :: [String.t()]
  def vertex_ids(state, query, adapter) do
    state = flush(state, adapter)

    cypher =
      "MATCH (v:Vertex)" <>
        Cypher.query_with_subgraph(query, "v", state.subgraph_ids) <> " RETURN v.id"

    state
    |> adapter.run_query(cypher, %{})
    |> Enum.map(fn [id] -> id end)
  end

  @spec available_vertex_types(struct(), module()) :: [module()]
  def available_vertex_types(state, adapter) do
    state = flush(state, adapter)

    state
    |> adapter.run_query(
      "MATCH (v:Vertex)" <>
        Cypher.subgraph_where(state.subgraph_ids, "v") <>
        " RETURN DISTINCT v.type ORDER BY v.type",
      %{}
    )
    |> Enum.map(fn [type_str] -> String.to_existing_atom(type_str) end)
  end

  @spec breadcrumbs(struct(), String.t(), module()) :: [struct()] | false
  def breadcrumbs(state, vertex_id, adapter) do
    state = flush(state, adapter)

    case adapter.run_query(
           state,
           """
           MATCH p = shortestPath((root:Vertex {id: 'root'})-[:TREE_EDGE*]->(target:Vertex {id: $id}))
           RETURN [n IN nodes(p) | n {.*}] AS path
           """,
           %{"id" => vertex_id}
         ) do
      [[path]] -> Enum.map(path, &Cypher.deserialize_vertex/1)
      [] -> false
    end
  end

  @spec get_short_path(struct(), String.t(), String.t(), module()) :: [struct()] | false
  def get_short_path(state, from_id, to_id, adapter) do
    state = flush(state, adapter)

    case adapter.run_query(
           state,
           """
           MATCH p = shortestPath((a:Vertex {id: $from_id})-[:EDGE*]->(b:Vertex {id: $to_id}))
           RETURN [n IN nodes(p) | n {.*}] AS path
           """,
           %{"from_id" => from_id, "to_id" => to_id}
         ) do
      [[path]] -> Enum.map(path, &Cypher.deserialize_vertex/1)
      [] -> false
    end
  end

  @spec navigation_children(struct(), String.t(), module()) :: %{term() => [struct()]}
  def navigation_children(state, vertex_id, adapter) do
    state = flush(state, adapter)

    state
    |> adapter.run_query(
      """
      MATCH (parent:Vertex {id: $id})-[r:TREE_EDGE]->(child:Vertex)
      RETURN r.label, child {.*}
      """,
      %{"id" => vertex_id}
    )
    |> Enum.group_by(fn [label, _] -> label end, fn [_, props] ->
      Cypher.deserialize_vertex(props)
    end)
    |> Map.new(fn {label, children} ->
      {String.to_existing_atom(label), Enum.sort_by(children, &Clarity.Vertex.name/1)}
    end)
  end

  @spec vertices_within_steps(
          struct(),
          String.t(),
          non_neg_integer(),
          non_neg_integer(),
          module()
        ) ::
          MapSet.t(String.t())
  def vertices_within_steps(state, vertex_id, max_out, max_in, adapter)
      when is_integer(max_out) and max_out >= 0 and is_integer(max_in) and max_in >= 0 do
    state = flush(state, adapter)

    state
    |> adapter.run_query(
      """
      MATCH (center:Vertex {id: $id})
      OPTIONAL MATCH (center)-[:EDGE*0..#{max_out}]->(out_v:Vertex)
      OPTIONAL MATCH (center)<-[:EDGE*0..#{max_in}]-(in_v:Vertex)
      WITH collect(DISTINCT out_v.id) + collect(DISTINCT in_v.id) AS ids
      UNWIND ids AS vid
      WITH DISTINCT vid WHERE vid IS NOT NULL
      RETURN vid
      """,
      %{"id" => vertex_id}
    )
    |> MapSet.new(fn [id] -> id end)
  end

  @spec reachable_from(struct(), [String.t()], module()) :: [String.t()]
  def reachable_from(state, source_vertex_ids, adapter) do
    state = flush(state, adapter)

    state
    |> adapter.run_query(
      """
      UNWIND $ids AS source_id
      MATCH (s:Vertex {id: source_id})
      MATCH (s)-[:EDGE*0..]->(reachable:Vertex)
      RETURN DISTINCT reachable.id
      """,
      %{"ids" => source_vertex_ids}
    )
    |> Enum.map(fn [id] -> id end)
  end

  @spec flush(struct(), module()) :: struct()
  defp flush(state, adapter) do
    WriteBuffer.flush(state, &adapter.run_batch/2)
  end
end
