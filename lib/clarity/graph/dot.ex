defmodule Clarity.Graph.DOT do
  @moduledoc false

  import Phoenix.HTML

  alias Clarity.Vertex
  alias Phoenix.HTML.Safe

  @type theme :: :light | :dark
  @type options :: [theme: theme(), highlight: :digraph.vertex() | [:digraph.vertex()]]

  @default_dot_options [
    theme: :light,
    highlight: []
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
      clarity_graph |> render_graph(options) |> indent(),
      clarity_graph |> render_edges() |> indent(),
      "}\n"
    ]
  end

  @spec render_graph(graph :: Clarity.Graph.t(), options :: options()) :: iodata()
  defp render_graph(clarity_graph, options) do
    clarity_graph
    |> Clarity.Graph.vertices()
    |> Enum.reject(fn
      %Vertex.Root{} -> true
      %Vertex.Content{} -> true
      _ -> false
    end)
    |> Enum.map(&{Vertex.graph_group(&1), &1})
    |> render_grouped_vertices(options)
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
          Vertex.render_name(vertex)
        ]),
        ", shape = ",
        Vertex.dot_shape(vertex),
        ", URL = \"#",
        Vertex.unique_id(vertex),
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

  @spec render_edges(graph :: Clarity.Graph.t()) :: iodata()
  defp render_edges(clarity_graph) do
    for edge <- Clarity.Graph.edges(clarity_graph),
        {_, from_vertex, to_vertex, label} = Clarity.Graph.edge(clarity_graph, edge),
        label != :content do
      # Only render if both vertices exist and neither is Root
      case {from_vertex, to_vertex} do
        {%Vertex.Root{}, _} ->
          []

        {_, %Vertex.Root{}} ->
          []

        {nil, _} ->
          []

        {_, nil} ->
          []

        {from, to} ->
          [
            encode_vertex_id(from),
            " -> ",
            encode_vertex_id(to),
            ";\n"
            # TODO: Show label?
            # " [label = \"",
            # escape_html_label(label),
            # "\"];\n"
          ]
      end
    end
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
  defp encode_vertex_id(%vertex_module{} = vertex) do
    encode_id([inspect(vertex_module), "_", vertex |> Vertex.graph_id() |> to_string()])
  end

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
