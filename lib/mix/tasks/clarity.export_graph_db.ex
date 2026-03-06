defmodule Mix.Tasks.Clarity.ExportGraphDb do
  @shortdoc "Exports the Clarity graph to Neo4j or ArcadeDB"
  @moduledoc """
  Exports the current Clarity graph to a graph database using batched HTTP requests.

  ## Options
  * `--target` or `-t`: `neo4j` or `arcade_db`
  * `--url`: Override the configured base URL
  * `--auth`: Basic auth in `user:pass` format
  * `--database`: Override the configured database name
  * `--clear`: Clear existing graph data before exporting
  * `--chunk-size`: Number of vertices/edges per batch request
  """

  use Mix.Task

  @requirements ["app.start"]

  @options [
    target: :string,
    url: :string,
    auth: :string,
    database: :string,
    clear: :boolean,
    chunk_size: :integer
  ]

  @aliases [
    t: :target
  ]

  @doc false
  @spec run(Clarity.t(), [String.t()]) :: {:ok, map()}
  def run(%Clarity{} = clarity, args) do
    {options, []} = OptionParser.parse!(args, strict: @options, aliases: @aliases)

    exporter = exporter_module!(Keyword.get(options, :target))
    export_opts = export_opts(options)

    result = exporter.export(clarity.graph, export_opts)
    print_result(Keyword.fetch!(options, :target), result)
    result
  end

  @impl Mix.Task
  def run(args) do
    clarity = Clarity.get(Clarity.Server, :complete)
    run(clarity, args)
  end

  @spec exporter_module!(String.t() | nil) :: module()
  defp exporter_module!("neo4j"), do: Clarity.Export.Neo4j
  defp exporter_module!("arcade_db"), do: Clarity.Export.ArcadeDB

  defp exporter_module!(nil),
    do: raise(ArgumentError, "missing required --target option (neo4j or arcade_db)")

  defp exporter_module!(other) do
    raise ArgumentError, "unsupported --target #{inspect(other)} (expected neo4j or arcade_db)"
  end

  @spec export_opts(keyword()) :: keyword()
  defp export_opts(options) do
    maybe_put_auth(options)
  end

  @spec maybe_put_auth(keyword()) :: keyword()
  defp maybe_put_auth(options) do
    case Keyword.fetch(options, :auth) do
      {:ok, auth} ->
        Keyword.put(options, :auth, parse_auth!(auth))

      :error ->
        options
    end
  end

  @spec parse_auth!(String.t()) :: {:basic, String.t(), String.t()}
  defp parse_auth!(value) do
    case String.split(value, ":", parts: 2) do
      [user, pass] -> {:basic, user, pass}
      _ -> raise ArgumentError, "expected --auth in user:pass format"
    end
  end

  @spec print_result(String.t(), {:ok, map()}) :: :ok
  defp print_result(target, {:ok, %{vertices: vertices, edges: edges, requests: requests}}) do
    Mix.shell().info(
      "Exported #{vertices} vertices and #{edges} edges to #{target} in #{requests} requests"
    )
  end
end
