defmodule Mix.Tasks.AshAtlas.ExportGraph do
  @shortdoc "Exports the Ash Atlas graph to a DOT file"
  @moduledoc """
  This task exports the Ash Atlas graph to a DOT file, which can be used for
  visualization with Graphviz.

  ## Options
  * `--out` or `-o`: The output file path. Defaults to `-` (stdout).
  * `--filter-vertices` or `-f`: A list of vertex names to filter the graph.
    Only vertices reachable from these will be included in the output.
  """

  use Mix.Task

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
  def run(args) do
    {options, []} = OptionParser.parse!(args, strict: @options, aliases: @aliases)

    out =
      case Keyword.get(options, :out, "-") do
        "-" -> IO.stream()
        path -> File.stream!(path, [:write, :utf8])
      end

    %AshAtlas{graph: graph} = atlas = AshAtlas.get()

    graph =
      case Keyword.get_values(options, :filter_vertices) do
        [] -> graph
        filters -> filter_graph_reachable_vertices(atlas, filters)
      end

    graph
    |> AshAtlas.Graph.to_dot()
    |> Enum.into(out, &List.wrap/1)
  end

  @spec filter_graph_reachable_vertices(atlas :: AshAtlas.t(), filter_vertices :: [String.t()]) ::
          :digraph.graph()
  defp filter_graph_reachable_vertices(atlas, filter_vertices) do
    filtered_graph = :digraph.new()
    filter_vertices = Enum.map(filter_vertices, &Map.fetch!(atlas.vertices, &1))

    for vertex <- :digraph.vertices(atlas.graph),
        Enum.any?(filter_vertices, fn filter ->
          vertex == filter or
            :digraph.get_short_path(atlas.graph, filter, vertex) != false
        end) do
      :digraph.add_vertex(filtered_graph, vertex)
    end

    for edge <- :digraph.edges(atlas.graph),
        {_edge, from, to, label} = :digraph.edge(atlas.graph, edge) do
      :digraph.add_edge(filtered_graph, from, to, label)
    end

    filtered_graph
  end
end
