defmodule Clarity.Export.Neo4j do
  @moduledoc """
  Exports an in-memory Clarity graph to Neo4j using batched HTTP requests.
  """

  alias Clarity.Export.Cypher
  alias Clarity.Graph

  @default_chunk_size 500

  @type result ::
          {:ok,
           %{vertices: non_neg_integer(), edges: non_neg_integer(), requests: non_neg_integer()}}

  @doc """
  Exports a graph to Neo4j.
  """
  @spec export(Graph.t(), keyword()) :: result()
  def export(%Graph{} = graph, opts \\ []) do
    config = merged_config(opts)
    vertices = Enum.map(Graph.vertices(graph), &Cypher.serialize_vertex/1)

    edges =
      graph
      |> Graph.edges()
      |> Enum.flat_map(fn edge_id ->
        case Graph.edge(graph, edge_id) do
          false -> []
          edge -> [Cypher.serialize_edge(edge)]
        end
      end)

    state = %{
      req: request_client(config),
      request_fun: Keyword.get(config, :request_fun, &Req.post/2),
      database: Keyword.fetch!(config, :database),
      requests: 0
    }

    chunk_size = Keyword.get(config, :chunk_size, @default_chunk_size)

    state
    |> ensure_constraints()
    |> maybe_clear(config)
    |> upload_vertices(vertices, chunk_size)
    |> upload_edges(edges, chunk_size)
    |> then(fn state ->
      {:ok, %{vertices: length(vertices), edges: length(edges), requests: state.requests}}
    end)
  end

  @spec ensure_constraints(map()) :: map()
  defp ensure_constraints(state) do
    run_cypher(
      state,
      "CREATE CONSTRAINT vertex_id IF NOT EXISTS FOR (v:Vertex) REQUIRE v.id IS UNIQUE",
      %{}
    )
  end

  @spec maybe_clear(map(), keyword()) :: map()
  defp maybe_clear(state, opts) do
    if Keyword.get(opts, :clear, false) do
      run_cypher(state, "MATCH (v:Vertex) DETACH DELETE v", %{})
    else
      state
    end
  end

  @spec upload_vertices(map(), [map()], pos_integer()) :: map()
  defp upload_vertices(state, vertices, chunk_size) do
    Enum.reduce(Enum.chunk_every(vertices, chunk_size), state, fn batch, acc ->
      run_cypher(
        acc,
        """
        UNWIND $batch AS row
        MERGE (v:Vertex {id: row.id})
        SET v = row
        """,
        %{"batch" => batch}
      )
    end)
  end

  @spec upload_edges(map(), [map()], pos_integer()) :: map()
  defp upload_edges(state, edges, chunk_size) do
    Enum.reduce(Enum.chunk_every(edges, chunk_size), state, fn batch, acc ->
      run_cypher(
        acc,
        """
        UNWIND $batch AS row
        MATCH (a:Vertex {id: row.from_id}), (b:Vertex {id: row.to_id})
        MERGE (a)-[:EDGE {label: row.label}]->(b)
        """,
        %{"batch" => batch}
      )
    end)
  end

  @spec run_cypher(map(), String.t(), map()) :: map()
  defp run_cypher(state, cypher, params) do
    body = %{"statements" => [%{"statement" => cypher, "parameters" => params}]}
    path = "/db/#{state.database}/tx/commit"

    case state.request_fun.(state.req, url: path, json: body) do
      {:ok, %{status: 200}} ->
        %{state | requests: state.requests + 1}

      {:ok, %{body: response_body}} ->
        raise "Neo4j export error: #{inspect(response_body)}"

      {:error, reason} ->
        raise "Neo4j export connection error: #{inspect(reason)}"
    end
  end

  @spec request_client(keyword()) :: term()
  defp request_client(config) do
    case Keyword.fetch(config, :req) do
      {:ok, req} ->
        req

      :error ->
        require_req!()

        {user, pass} = basic_auth_tuple(Keyword.fetch!(config, :auth))

        Req.new(
          base_url: Keyword.fetch!(config, :url),
          auth: {:basic, "#{user}:#{pass}"},
          headers: [{"content-type", "application/json"}, {"accept", "application/json"}]
        )
    end
  end

  @spec merged_config(keyword()) :: keyword()
  defp merged_config(opts) do
    :clarity
    |> Application.get_env(__MODULE__, [])
    |> Keyword.merge(opts)
    |> Keyword.put_new(:url, "http://localhost:7474")
    |> Keyword.put_new(:auth, {:basic, "neo4j", "neo4j"})
    |> Keyword.put_new(:database, "neo4j")
  end

  @spec basic_auth_tuple({:basic, String.t(), String.t()}) :: {String.t(), String.t()}
  defp basic_auth_tuple({:basic, user, pass}), do: {user, pass}

  defp basic_auth_tuple(other) do
    raise ArgumentError,
          "expected :auth to be {:basic, user, pass}, got: #{inspect(other)}"
  end

  @spec require_req!() :: :ok
  defp require_req! do
    if Code.ensure_loaded?(Req) do
      :ok
    else
      raise "Req is required for graph database export. Add {:req, \"~> 0.5\", optional: true} to your dependencies."
    end
  end
end
