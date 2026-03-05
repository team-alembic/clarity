defmodule Clarity.Graph.Backend.ArcadeDB do
  @moduledoc """
  Graph backend using ArcadeDB via its HTTP API.

  Stores graph data in an ArcadeDB database, using Cypher queries over HTTP.
  Requires `Req` (available in Phoenix projects) for HTTP communication.

  ## Configuration

      config :clarity, :graph_backend, Clarity.Graph.Backend.ArcadeDB
      config :clarity, Clarity.Graph.Backend.ArcadeDB,
        url: "http://localhost:2480",
        auth: {:basic, "root", "password"},
        database: "clarity"
  """

  @behaviour Clarity.Graph.Backend

  alias Clarity.Graph.Backend
  alias Clarity.Graph.Backend.Cypher

  defstruct [
    :url,
    :auth,
    :database,
    :req,
    write_buffer: [],
    subgraph_ids: nil,
    update_count: 0
  ]

  @type t :: %__MODULE__{
          url: String.t(),
          auth: {:basic, String.t(), String.t()},
          database: String.t(),
          req: term(),
          write_buffer: [{String.t(), map()}],
          subgraph_ids: MapSet.t() | nil,
          update_count: non_neg_integer()
        }

  @batch_size 100

  @impl Backend
  def new(opts \\ []) do
    config = Application.get_env(:clarity, __MODULE__, [])
    merged = Keyword.merge(config, opts)

    url = Keyword.get(merged, :url, "http://localhost:2480")
    auth = Keyword.get(merged, :auth, {:basic, "root", "root"})
    database = Keyword.get(merged, :database, "clarity")

    req = build_req(url, auth)

    state = %__MODULE__{
      url: url,
      auth: auth,
      database: database,
      req: req
    }

    ensure_schema(state)

    state
  end

  @impl Backend
  def delete(state, _subgraph) do
    execute_cypher(state, "MATCH (n) DETACH DELETE n", %{})
    :ok
  end

  @impl Backend
  def clear(state) do
    execute_cypher(state, "MATCH (n) DETACH DELETE n", %{})
    %{state | update_count: state.update_count + 1, write_buffer: []}
  end

  @impl Backend
  def handover(state, _pid, _subgraph), do: state

  @impl Backend
  def add_vertex(state, vertex_id, vertex_type, vertex_struct, caused_by_id) do
    props = Cypher.serialize_vertex(vertex_id, vertex_type, vertex_struct)

    statements = [
      {"MERGE (v:Vertex {id: $id}) SET v = $props", %{"id" => vertex_id, "props" => props}},
      {"MATCH (a:Vertex {id: $from_id}), (b:Vertex {id: $to_id}) MERGE (a)-[:CAUSED_BY]->(b)",
       %{"from_id" => caused_by_id, "to_id" => vertex_id}}
    ]

    state = buffer_statements(state, statements)
    %{state | update_count: state.update_count + 1}
  end

  @impl Backend
  def add_edge(state, from_id, to_id, label) do
    statement =
      {"""
       MATCH (a:Vertex {id: $from_id}), (b:Vertex {id: $to_id})
       MERGE (a)-[r:EDGE {label: $label}]->(b)
       MERGE (a)-[t:TREE_EDGE {label: $label}]->(b)
       """,
       %{
         "from_id" => from_id,
         "to_id" => to_id,
         "label" => Cypher.serialize_field_value(label)
       }}

    state = buffer_statements(state, [statement])
    %{state | update_count: state.update_count + 1}
  end

  @impl Backend
  def purge(state, vertex_id) do
    state = flush_buffer(state)

    rows =
      execute_cypher(
        state,
        """
        MATCH (start:Vertex {id: $id})-[:CAUSED_BY*0..]->(n:Vertex)
        WITH n, n {.*} AS props
        DETACH DELETE n
        RETURN props
        """,
        %{"id" => vertex_id}
      )

    purged = Enum.map(rows, fn [props] -> Cypher.deserialize_vertex(props) end)
    {purged, %{state | update_count: state.update_count + 1}}
  end

  @impl Backend
  def get_vertex(state, vertex_id) do
    state = flush_buffer(state)

    case execute_cypher(state, "MATCH (v:Vertex {id: $id}) RETURN v {.*}", %{"id" => vertex_id}) do
      [[props]] -> Cypher.deserialize_vertex(props)
      [] -> nil
    end
  end

  @impl Backend
  def vertex_count(state) do
    state = flush_buffer(state)

    case execute_cypher(
           state,
           "MATCH (v:Vertex)#{subgraph_where(state, "v")} RETURN count(v) AS c",
           %{}
         ) do
      [[count]] -> count
      [] -> 0
    end
  end

  @impl Backend
  def get_update_count(state), do: state.update_count

  @impl Backend
  def out_neighbors(state, vertex_id) do
    state = flush_buffer(state)

    state
    |> execute_cypher(
      "MATCH (a:Vertex {id: $id})-[:EDGE]->(b:Vertex)#{subgraph_where(state, "b")} RETURN b {.*}",
      %{"id" => vertex_id}
    )
    |> Enum.map(fn [props] -> Cypher.deserialize_vertex(props) end)
  end

  @impl Backend
  def in_neighbors(state, vertex_id) do
    state = flush_buffer(state)

    state
    |> execute_cypher(
      "MATCH (a:Vertex)-[:EDGE]->(b:Vertex {id: $id})#{subgraph_where(state, "a")} RETURN a {.*}",
      %{"id" => vertex_id}
    )
    |> Enum.map(fn [props] -> Cypher.deserialize_vertex(props) end)
  end

  @impl Backend
  def out_edges(state, vertex_id) do
    state = flush_buffer(state)

    state
    |> execute_cypher(
      "MATCH (a:Vertex {id: $id})-[r:EDGE]->(b:Vertex) RETURN id(r)",
      %{"id" => vertex_id}
    )
    |> Enum.map(fn [id] -> id end)
  end

  @impl Backend
  def in_edges(state, vertex_id) do
    state = flush_buffer(state)

    state
    |> execute_cypher(
      "MATCH (a:Vertex)-[r:EDGE]->(b:Vertex {id: $id}) RETURN id(r)",
      %{"id" => vertex_id}
    )
    |> Enum.map(fn [id] -> id end)
  end

  @impl Backend
  def edges(state) do
    state = flush_buffer(state)

    state
    |> execute_cypher(
      "MATCH (a:Vertex)-[r:EDGE]->(b:Vertex)#{subgraph_where_multi(state, ["a", "b"])} RETURN id(r)",
      %{}
    )
    |> Enum.map(fn [id] -> id end)
  end

  @impl Backend
  def edge(state, edge_id) do
    state = flush_buffer(state)

    case execute_cypher(
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

  @impl Backend
  def in_degree(state, vertex_id) do
    state = flush_buffer(state)

    case execute_cypher(
           state,
           "MATCH (a:Vertex)-[:EDGE]->(b:Vertex {id: $id}) RETURN count(a)",
           %{"id" => vertex_id}
         ) do
      [[count]] -> count
      [] -> 0
    end
  end

  @impl Backend
  def in_degree(state, vertex_id, label) do
    state = flush_buffer(state)

    case execute_cypher(
           state,
           "MATCH (a:Vertex)-[r:EDGE {label: $label}]->(b:Vertex {id: $id}) RETURN count(a)",
           %{"id" => vertex_id, "label" => Cypher.serialize_field_value(label)}
         ) do
      [[count]] -> count
      [] -> 0
    end
  end

  @impl Backend
  def out_degree(state, vertex_id) do
    state = flush_buffer(state)

    case execute_cypher(
           state,
           "MATCH (a:Vertex {id: $id})-[:EDGE]->(b:Vertex) RETURN count(b)",
           %{"id" => vertex_id}
         ) do
      [[count]] -> count
      [] -> 0
    end
  end

  @impl Backend
  def out_degree(state, vertex_id, label) do
    state = flush_buffer(state)

    case execute_cypher(
           state,
           "MATCH (a:Vertex {id: $id})-[r:EDGE {label: $label}]->(b:Vertex) RETURN count(b)",
           %{"id" => vertex_id, "label" => Cypher.serialize_field_value(label)}
         ) do
      [[count]] -> count
      [] -> 0
    end
  end

  @impl Backend
  def vertices(state, query) do
    state = flush_buffer(state)
    where = Cypher.query_to_cypher(query, "v")

    subgraph_clause =
      case state.subgraph_ids do
        nil -> ""
        ids -> " AND v.id IN #{cypher_list(MapSet.to_list(ids))}"
      end

    cypher =
      if where == "" do
        "MATCH (v:Vertex)#{if subgraph_clause == "", do: "", else: " WHERE true#{subgraph_clause}"} RETURN v {.*}"
      else
        "MATCH (v:Vertex)#{where}#{subgraph_clause} RETURN v {.*}"
      end

    state
    |> execute_cypher(cypher, %{})
    |> Enum.map(fn [props] -> Cypher.deserialize_vertex(props) end)
  end

  @impl Backend
  def vertex_ids(state, query) do
    state = flush_buffer(state)
    where = Cypher.query_to_cypher(query, "v")

    subgraph_clause =
      case state.subgraph_ids do
        nil -> ""
        ids -> " AND v.id IN #{cypher_list(MapSet.to_list(ids))}"
      end

    cypher =
      if where == "" do
        "MATCH (v:Vertex)#{if subgraph_clause == "", do: "", else: " WHERE true#{subgraph_clause}"} RETURN v.id"
      else
        "MATCH (v:Vertex)#{where}#{subgraph_clause} RETURN v.id"
      end

    state
    |> execute_cypher(cypher, %{})
    |> Enum.map(fn [id] -> id end)
  end

  @impl Backend
  def available_vertex_types(state) do
    state = flush_buffer(state)

    state
    |> execute_cypher(
      "MATCH (v:Vertex)#{subgraph_where(state, "v")} RETURN DISTINCT v.type ORDER BY v.type",
      %{}
    )
    |> Enum.map(fn [type_str] -> String.to_existing_atom(type_str) end)
  end

  @impl Backend
  def breadcrumbs(state, vertex_id) do
    state = flush_buffer(state)

    case execute_cypher(
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

  @impl Backend
  def get_short_path(state, from_id, to_id) do
    state = flush_buffer(state)

    case execute_cypher(
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

  @impl Backend
  def navigation_children(state, vertex_id) do
    state = flush_buffer(state)

    state
    |> execute_cypher(
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

  @impl Backend
  def vertices_within_steps(state, vertex_id, max_out, max_in) do
    state = flush_buffer(state)

    state
    |> execute_cypher(
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

  @impl Backend
  def reachable_from(state, source_vertex_ids) do
    state = flush_buffer(state)

    state
    |> execute_cypher(
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

  @impl Backend
  def create_subgraph(state, vertex_ids) do
    %{state | subgraph_ids: MapSet.new(vertex_ids)}
  end

  @impl Backend
  def persist(state, path) do
    state = flush_buffer(state)

    rows =
      execute_cypher(
        state,
        """
        MATCH (v:Vertex)
        OPTIONAL MATCH (v)-[r]->(v2:Vertex)
        RETURN collect(DISTINCT v {.*}) AS vertices,
               collect(DISTINCT {from: startNode(r).id, to: endNode(r).id, type: type(r), label: r.label}) AS edges
        """,
        %{}
      )

    case rows do
      [[vertices, raw_edges]] ->
        data = %{vertices: vertices, edges: raw_edges, update_count: state.update_count}
        binary = :erlang.term_to_binary(data)

        with :ok <- File.mkdir_p(path) do
          File.write(Path.join(path, "arcadedb_export.etf"), binary)
        end

      [] ->
        :ok
    end
  end

  @impl Backend
  def load(path, _opts \\ []) do
    file = Path.join(path, "arcadedb_export.etf")

    case File.read(file) do
      {:ok, binary} ->
        data = :erlang.binary_to_term(binary)
        state = new()

        Enum.each(data.vertices, fn props ->
          execute_cypher(state, "CREATE (v:Vertex) SET v = $props", %{"props" => props})
        end)

        Enum.each(data.edges, fn edge ->
          execute_cypher(
            state,
            """
            MATCH (a:Vertex {id: $from}), (b:Vertex {id: $to})
            CREATE (a)-[:#{edge["type"]} {label: $label}]->(b)
            """,
            %{"from" => edge["from"], "to" => edge["to"], "label" => edge["label"]}
          )
        end)

        {:ok, %{state | update_count: data.update_count}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # HTTP client

  @spec build_req(String.t(), {:basic, String.t(), String.t()}) :: term()
  defp build_req(url, {:basic, user, pass}) do
    Req.new(
      base_url: url,
      auth: {:basic, "#{user}:#{pass}"},
      headers: [{"content-type", "application/json"}, {"accept", "application/json"}]
    )
  end

  @spec execute_cypher(t(), String.t(), map()) :: [[term()]]
  defp execute_cypher(state, cypher, params) do
    body = %{
      "language" => "cypher",
      "command" => cypher,
      "params" => params
    }

    path = "/api/v1/command/#{state.database}"

    case Req.post(state.req, url: path, json: body) do
      {:ok, %{status: 200, body: %{"result" => result}}} ->
        Enum.map(result, &extract_row/1)

      {:ok, %{body: body}} ->
        raise "ArcadeDB error: #{inspect(body)}"

      {:error, reason} ->
        raise "ArcadeDB connection error: #{inspect(reason)}"
    end
  end

  # Write buffering

  @spec extract_row(map() | list() | term()) :: [term()]
  defp extract_row(%{"row" => values}), do: values
  defp extract_row(values) when is_list(values), do: values
  defp extract_row(other), do: [other]

  @spec buffer_statements(t(), [{String.t(), map()}]) :: t()
  defp buffer_statements(state, statements) do
    new_buffer = state.write_buffer ++ statements

    if length(new_buffer) >= @batch_size do
      flush_buffer(%{state | write_buffer: new_buffer})
    else
      %{state | write_buffer: new_buffer}
    end
  end

  @spec flush_buffer(t()) :: t()
  defp flush_buffer(%{write_buffer: []} = state), do: state

  defp flush_buffer(state) do
    Enum.each(state.write_buffer, fn {cypher, params} ->
      execute_cypher(state, cypher, params)
    end)

    %{state | write_buffer: []}
  end

  # Schema setup

  @spec ensure_schema(t()) :: :ok
  defp ensure_schema(state) do
    try do
      execute_cypher(state, "CREATE VERTEX TYPE Vertex IF NOT EXISTS", %{})
      execute_cypher(state, "CREATE EDGE TYPE EDGE IF NOT EXISTS", %{})
      execute_cypher(state, "CREATE EDGE TYPE TREE_EDGE IF NOT EXISTS", %{})
      execute_cypher(state, "CREATE EDGE TYPE CAUSED_BY IF NOT EXISTS", %{})
    rescue
      _ -> :ok
    end

    :ok
  end

  # Subgraph helpers

  @spec subgraph_where(t(), String.t()) :: String.t()
  defp subgraph_where(%{subgraph_ids: nil}, _var), do: ""

  defp subgraph_where(%{subgraph_ids: ids}, var) do
    " WHERE #{var}.id IN #{cypher_list(MapSet.to_list(ids))}"
  end

  @spec subgraph_where_multi(t(), [String.t()]) :: String.t()
  defp subgraph_where_multi(%{subgraph_ids: nil}, _vars), do: ""

  defp subgraph_where_multi(%{subgraph_ids: ids}, vars) do
    id_list = cypher_list(MapSet.to_list(ids))
    clauses = Enum.map_join(vars, " AND ", fn var -> "#{var}.id IN #{id_list}" end)
    " WHERE #{clauses}"
  end

  @spec cypher_list([String.t()]) :: String.t()
  defp cypher_list(items) do
    "[#{Enum.map_join(items, ", ", &"'#{Cypher.escape_cypher_string(&1)}'")}]"
  end
end
