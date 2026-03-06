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
  alias Clarity.Graph.Backend.CypherRemote

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
  @export_file "arcadedb_export.etf"

  @impl Backend
  def new(opts \\ []) do
    config = Application.get_env(:clarity, __MODULE__, [])
    merged = Keyword.merge(config, opts)

    url = Keyword.get(merged, :url, "http://localhost:2480")
    auth = Keyword.get(merged, :auth, {:basic, "root", "root"})
    database = Keyword.get(merged, :database, "clarity")
    req = build_req(url, auth)

    state = %__MODULE__{url: url, auth: auth, database: database, req: req}
    ensure_schema(state)
    state
  end

  @impl Backend
  def delete(state, subgraph), do: CypherRemote.delete(state, subgraph, __MODULE__)

  @impl Backend
  def clear(state), do: CypherRemote.clear(state, __MODULE__)

  @impl Backend
  def handover(state, pid, subgraph), do: CypherRemote.handover(state, pid, subgraph)

  @impl Backend
  def add_vertex(state, vertex_id, vertex_type, vertex_struct, caused_by_id) do
    CypherRemote.add_vertex(
      state,
      vertex_id,
      vertex_type,
      vertex_struct,
      caused_by_id,
      __MODULE__,
      @batch_size
    )
  end

  @impl Backend
  def add_edge(state, from_id, to_id, label) do
    CypherRemote.add_edge(state, from_id, to_id, label, __MODULE__, @batch_size)
  end

  @impl Backend
  def purge(state, vertex_id), do: CypherRemote.purge(state, vertex_id, __MODULE__)

  @impl Backend
  def get_vertex(state, vertex_id), do: CypherRemote.get_vertex(state, vertex_id, __MODULE__)

  @impl Backend
  def vertex_count(state), do: CypherRemote.vertex_count(state, __MODULE__)

  @impl Backend
  def get_update_count(state), do: CypherRemote.get_update_count(state)

  @impl Backend
  def out_neighbors(state, vertex_id),
    do: CypherRemote.out_neighbors(state, vertex_id, __MODULE__)

  @impl Backend
  def in_neighbors(state, vertex_id), do: CypherRemote.in_neighbors(state, vertex_id, __MODULE__)

  @impl Backend
  def out_edges(state, vertex_id), do: CypherRemote.out_edges(state, vertex_id, __MODULE__)

  @impl Backend
  def in_edges(state, vertex_id), do: CypherRemote.in_edges(state, vertex_id, __MODULE__)

  @impl Backend
  def edges(state), do: CypherRemote.edges(state, __MODULE__)

  @impl Backend
  def edge(state, edge_id), do: CypherRemote.edge(state, edge_id, __MODULE__)

  @impl Backend
  def in_degree(state, vertex_id), do: CypherRemote.in_degree(state, vertex_id, __MODULE__)

  @impl Backend
  def in_degree(state, vertex_id, label),
    do: CypherRemote.in_degree(state, vertex_id, label, __MODULE__)

  @impl Backend
  def out_degree(state, vertex_id), do: CypherRemote.out_degree(state, vertex_id, __MODULE__)

  @impl Backend
  def out_degree(state, vertex_id, label),
    do: CypherRemote.out_degree(state, vertex_id, label, __MODULE__)

  @impl Backend
  def vertices(state, query), do: CypherRemote.vertices(state, query, __MODULE__)

  @impl Backend
  def vertex_ids(state, query), do: CypherRemote.vertex_ids(state, query, __MODULE__)

  @impl Backend
  def available_vertex_types(state), do: CypherRemote.available_vertex_types(state, __MODULE__)

  @impl Backend
  def breadcrumbs(state, vertex_id), do: CypherRemote.breadcrumbs(state, vertex_id, __MODULE__)

  @impl Backend
  def get_short_path(state, from_id, to_id),
    do: CypherRemote.get_short_path(state, from_id, to_id, __MODULE__)

  @impl Backend
  def navigation_children(state, vertex_id),
    do: CypherRemote.navigation_children(state, vertex_id, __MODULE__)

  @impl Backend
  def vertices_within_steps(state, vertex_id, max_out, max_in) do
    CypherRemote.vertices_within_steps(state, vertex_id, max_out, max_in, __MODULE__)
  end

  @impl Backend
  def reachable_from(state, source_vertex_ids),
    do: CypherRemote.reachable_from(state, source_vertex_ids, __MODULE__)

  @impl Backend
  def create_subgraph(state, vertex_ids), do: CypherRemote.create_subgraph(state, vertex_ids)

  @impl Backend
  def persist(state, path), do: CypherRemote.persist(state, path, @export_file, __MODULE__)

  @impl Backend
  def load(path, _opts \\ []) do
    file = Path.join(path, @export_file)

    case File.read(file) do
      {:ok, binary} ->
        data = :erlang.binary_to_term(binary)
        state = new()

        Enum.each(data.vertices, fn props ->
          run_query(state, "CREATE (v:Vertex) SET v = $props", %{"props" => props})
        end)

        Enum.each(data.edges, fn edge ->
          rel_type = validate_rel_type!(edge["type"])

          run_query(
            state,
            """
            MATCH (a:Vertex {id: $from}), (b:Vertex {id: $to})
            CREATE (a)-[:#{rel_type} {label: $label}]->(b)
            """,
            %{"from" => edge["from"], "to" => edge["to"], "label" => edge["label"]}
          )
        end)

        {:ok, %{state | update_count: data.update_count}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc false
  @spec statement(String.t(), map()) :: {String.t(), map()}
  def statement(cypher, params), do: {cypher, params}

  @doc false
  @spec run_query(t(), String.t(), map()) :: [[term()]]
  def run_query(state, cypher, params) do
    body = %{"language" => "cypher", "command" => cypher, "params" => params}
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

  @doc false
  @spec run_batch(t(), [{String.t(), map()}]) :: [[term()]]
  def run_batch(state, statements) do
    body = %{
      "language" => "cypher",
      "serializer" => "record",
      "operations" => Enum.map(statements, fn {cypher, params} ->
        %{"language" => "cypher", "command" => cypher, "params" => params}
      end)
    }

    path = "/api/v1/batch/#{state.database}"

    case Req.post(state.req, url: path, json: body) do
      {:ok, %{status: 200, body: %{"result" => result}}} ->
        Enum.map(result, &extract_row/1)

      {:ok, %{status: 200}} ->
        []

      {:ok, _} ->
        Enum.flat_map(statements, fn {cypher, params} -> run_query(state, cypher, params) end)

      {:error, _} ->
        Enum.flat_map(statements, fn {cypher, params} -> run_query(state, cypher, params) end)
    end
  end

  @spec build_req(String.t(), {:basic, String.t(), String.t()}) :: term()
  defp build_req(url, {:basic, user, pass}) do
    Req.new(
      base_url: url,
      auth: {:basic, "#{user}:#{pass}"},
      headers: [{"content-type", "application/json"}, {"accept", "application/json"}]
    )
  end

  @spec extract_row(map() | list() | term()) :: [term()]
  defp extract_row(%{"row" => values}), do: values
  defp extract_row(values) when is_list(values), do: values
  defp extract_row(other), do: [other]

  @allowed_rel_types ~w(EDGE TREE_EDGE CAUSED_BY)

  @spec validate_rel_type!(String.t()) :: String.t()
  defp validate_rel_type!(type) when type in @allowed_rel_types, do: type

  defp validate_rel_type!(type),
    do: raise(ArgumentError, "invalid relationship type: #{inspect(type)}")

  @spec ensure_schema(t()) :: :ok
  defp ensure_schema(state) do
    run_query(state, "CREATE VERTEX TYPE Vertex IF NOT EXISTS", %{})
    run_query(state, "CREATE EDGE TYPE EDGE IF NOT EXISTS", %{})
    run_query(state, "CREATE EDGE TYPE TREE_EDGE IF NOT EXISTS", %{})
    run_query(state, "CREATE EDGE TYPE CAUSED_BY IF NOT EXISTS", %{})
    :ok
  end
end
