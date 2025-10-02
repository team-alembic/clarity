defmodule Clarity.Graph.DOT do
  @moduledoc false

  import Phoenix.HTML

  alias Clarity.Vertex
  alias Phoenix.HTML.Safe

  @type theme :: :light | :dark
  @type options :: [
          theme: theme(),
          highlight: Vertex.t() | [Vertex.t()],
          max_vertices: pos_integer() | :infinity
        ]

  @default_dot_options [
    theme: :light,
    highlight: [],
    max_vertices: :infinity
  ]

  @doc """
  Converts Clarity Graph to DOT format.
  """
  @spec to_dot(graph :: Clarity.Graph.t(), options :: options()) :: iodata()
  def to_dot(clarity_graph, options \\ []) do
    options =
      @default_dot_options
      |> Keyword.merge(options)
      |> Keyword.update!(:highlight, &List.wrap/1)

    {graph_content, included_vertices} = render_graph(clarity_graph, options)

    [
      "digraph {\n",
      "  bgcolor = transparent;\n",
      "  fontname = \"system-ui\";\n",
      if options[:theme] == :dark do
        [
          "  color = \"#9ca3af\";\n",
          "  fontcolor = \"#f0f0f0\";\n"
        ]
      else
        []
      end,
      "  node [\n",
      "    tooltip = \" \";\n",
      "    fontname = \"system-ui\";\n",
      if options[:theme] == :dark do
        [
          "    fontcolor = \"#fff\";\n",
          "    style = filled;\n",
          "    fillcolor = \"#374151\";\n",
          "    color = \"#9ca3af\";\n"
        ]
      else
        []
      end,
      "  ];\n",
      "  edge [\n",
      "    fontname = \"system-ui\";\n",
      if options[:theme] == :dark do
        [
          "    fontcolor = \"#e5e7eb\";\n",
          "    color = \"#d1d5db\";\n"
        ]
      else
        []
      end,
      "  ];\n",
      "  rankdir = LR;\n",
      indent(graph_content),
      clarity_graph |> render_edges(included_vertices) |> indent(),
      "}\n"
    ]
  end

  @spec render_graph(graph :: Clarity.Graph.t(), options :: options()) ::
          {iodata(), MapSet.t(Vertex.t())}
  defp render_graph(clarity_graph, options) do
    all_vertices =
      clarity_graph
      |> Clarity.Graph.vertices()
      |> Enum.reject(&match?(%Vertex.Root{}, &1))

    highlighted = options[:highlight]

    # Ensure highlighted vertices are always included
    {highlighted_vertices, other_vertices} =
      Enum.split_with(all_vertices, fn v -> v in highlighted end)

    # Take up to max_vertices from other vertices, always including highlighted ones
    {vertices, was_limited?} =
      case options[:max_vertices] do
        :infinity ->
          {all_vertices, false}

        max_count ->
          remaining_slots = max(0, max_count - length(highlighted_vertices))
          other_included = Enum.take(other_vertices, remaining_slots)
          vertices = highlighted_vertices ++ other_included
          {vertices, length(all_vertices) > length(vertices)}
      end

    rendered =
      vertices
      |> Enum.map(&{Vertex.GraphGroupProvider.graph_group(&1), &1})
      |> render_grouped_vertices(options)

    vertex_set = MapSet.new(vertices)

    rendered_with_warning =
      if was_limited? do
        total_count = length(all_vertices)
        shown_count = length(vertices)

        [
          rendered,
          render_warning_vertex(total_count, shown_count, options)
        ]
      else
        rendered
      end

    {rendered_with_warning, vertex_set}
  end

  @spec render_grouped_vertices(vertices :: [{[String.t()], Vertex.t()}], options :: options()) ::
          iodata()
  defp render_grouped_vertices(vertices, options) do
    {here, nested} =
      vertices
      |> Enum.group_by(
        fn
          {[group | _rest], _vertex} -> group
          {[], _vertex} -> nil
        end,
        fn
          {[_group | rest], vertex} -> {rest, vertex}
          {[], vertex} -> vertex
        end
      )
      |> Map.split([nil])

    [
      render_vertices(here[nil] || [], options),
      for {group, vertices} <- nested do
        [
          "subgraph ",
          encode_id(["cluster_", group]),
          " {\n",
          "  label = ",
          escape_html_label([
            raw("<FONT POINT-SIZE=\"10\">"),
            group,
            raw("</FONT>")
          ]),
          ";\n",
          "  style = rounded;\n",
          vertices |> render_grouped_vertices(options) |> indent(),
          "}\n"
        ]
      end
    ]
  end

  @spec render_vertices(vertices :: [Vertex.t()], options :: options()) :: iodata()
  defp render_vertices(vertices, options) do
    for vertex <- vertices do
      [
        encode_vertex_id(vertex),
        " [label = ",
        escape_html_label([
          raw("<I><FONT POINT-SIZE=\"8\">"),
          Vertex.type_label(vertex),
          raw("</FONT></I><BR />"),
          Vertex.name(vertex)
        ]),
        ", shape = ",
        Vertex.GraphShapeProvider.shape(vertex),
        ", URL = \"#",
        Vertex.id(vertex),
        "\"",
        case {vertex in options[:highlight], options[:theme]} do
          {true, :dark} -> ", style = filled, fillcolor = \"#ff5757\", color = \"#ff5757\""
          {true, :light} -> ", style = filled, fillcolor = \"#FF914D\", color = \"#FF914D\""
          _ -> ""
        end,
        "];\n"
      ]
    end
  end

  @spec render_edges(graph :: Clarity.Graph.t(), included_vertices :: MapSet.t(Vertex.t())) ::
          iodata()
  defp render_edges(clarity_graph, included_vertices) do
    for edge <- Clarity.Graph.edges(clarity_graph),
        {_, from_vertex, to_vertex, label} = Clarity.Graph.edge(clarity_graph, edge),
        label != :content,
        MapSet.member?(included_vertices, from_vertex),
        MapSet.member?(included_vertices, to_vertex) do
      [
        encode_vertex_id(from_vertex),
        " -> ",
        encode_vertex_id(to_vertex),
        ";\n"
        # TODO: Show label?
        # " [label = \"",
        # escape_html_label(label),
        # "\"];\n"
      ]
    end
  end

  @spec render_warning_vertex(
          total_count :: non_neg_integer(),
          shown_count :: non_neg_integer(),
          options :: options()
        ) :: iodata()
  defp render_warning_vertex(total_count, shown_count, options) do
    hidden_count = total_count - shown_count

    [
      "<warning_vertex> [label = ",
      escape_html_label([
        raw("<FONT POINT-SIZE=\"10\"><B>⚠ Graph Truncated</B></FONT>"),
        raw("<BR />"),
        raw("<FONT POINT-SIZE=\"8\">"),
        "Showing #{shown_count} of #{total_count} vertices",
        raw("<BR />"),
        "#{hidden_count} vertices hidden",
        raw("</FONT>")
      ]),
      ", shape = box",
      case options[:theme] do
        :dark ->
          ", style = filled, fillcolor = \"#991b1b\", color = \"#ff5757\", fontcolor = \"#fff\""

        _ ->
          ", style = filled, fillcolor = \"#fecaca\", color = \"#dc2626\", fontcolor = \"#7f1d1d\""
      end,
      "];\n"
    ]
  end

  @spec indent(content :: iodata()) :: iodata()
  defp indent(content) do
    [
      content
      |> IO.iodata_to_binary()
      |> String.split("\n", trim: true)
      |> Enum.map(&["\n  ", &1]),
      "\n"
    ]
  end

  @spec encode_vertex_id(vertex :: Vertex.t()) :: iodata()
  defp encode_vertex_id(vertex), do: vertex |> Vertex.id() |> encode_id()

  @spec encode_id(id :: iodata()) :: iodata()
  defp encode_id(id) do
    {:safe, content} = id |> to_string() |> html_escape()
    [?<, content, ?>]
  end

  @spec escape_html_label(content :: Safe.t()) :: iodata()
  defp escape_html_label(text) do
    [?<, Safe.to_iodata(text), ?>]
  end
end
