defmodule Mix.Tasks.Clarity.ExportGraph do
  @shortdoc "Exports the Clarity graph to a DOT file"
  @moduledoc """
  This task exports the Clarity graph to a DOT file, which can be used for
  visualization with Graphviz.

  ## Options
  * `--out` or `-o`: The output file path. Defaults to `-` (stdout).
  * `--filter-vertices` or `-f`: A list of vertex names to filter the graph.
    Only vertices reachable from these will be included in the output.
  """

  use Mix.Task

  alias Clarity.Graph.DOT
  alias Clarity.Graph.Filter

  @requirements ["app.start"]

  @options [
    out: :string,
    filter_vertices: [:string, :keep]
  ]

  @aliases [
    o: :out,
    f: :filter_vertices
  ]

  @impl Mix.Task
  def run(clarity \\ Clarity.get(Clarity.Server, :complete), args) do
    {options, []} = OptionParser.parse!(args, strict: @options, aliases: @aliases)

    out =
      case Keyword.get(options, :out, "-") do
        "-" -> IO.stream()
        path -> File.stream!(path, [:write, :utf8])
      end

    %Clarity{graph: clarity_graph} = clarity

    case_result =
      case Keyword.get_values(options, :filter_vertices) do
        [] ->
          DOT.to_dot(clarity_graph)

        filter_vertex_ids ->
          source_vertices = lookup_vertices(clarity_graph, filter_vertex_ids)

          filtered_clarity_graph =
            Clarity.Graph.filter(clarity_graph, Filter.reachable_from(source_vertices))

          DOT.to_dot(filtered_clarity_graph)
      end

    Enum.into(case_result, out, &List.wrap/1)
  end

  @spec lookup_vertices(Clarity.Graph.t(), [String.t()]) :: [Clarity.Vertex.t()]
  defp lookup_vertices(graph, vertex_ids) do
    Enum.map(vertex_ids, fn vertex_id ->
      case Clarity.Graph.get_vertex(graph, vertex_id) do
        nil -> raise "Vertex with ID '#{vertex_id}' not found in graph"
        vertex -> vertex
      end
    end)
  end
end
