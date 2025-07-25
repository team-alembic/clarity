defmodule AshAtlas.Graph do
  @moduledoc false

  import Phoenix.HTML

  alias AshAtlas.Vertex
  alias Phoenix.HTML.Safe

  @type theme :: :light | :dark
  @type options :: [theme: theme()]

  @default_dot_options [
    theme: :light
  ]

  @spec to_dot(graph :: :digraph.graph(), options :: options()) :: iodata()
  def to_dot(graph, options \\ []) do
    options = Keyword.merge(@default_dot_options, options)

    [
      "digraph {\n",
      "  bgcolor = transparent;\n",
      "  fontname = \"system-ui\";\n",
      if options[:theme] == :dark do
        [
          "  color = \"#9ca3af\";\n",
          "  fontcolor = \"#f0f0f0\";\n"
        ]
      end,
      "  node [\n",
      "    fontname = \"system-ui\";\n",
      if options[:theme] == :dark do
        [
          "    fontcolor = \"#fff\";\n",
          "    style = filled;\n",
          "    fillcolor = \"#374151\";\n",
          "    color = \"#9ca3af\";\n"
        ]
      end,
      "  ];\n",
      "  edge [\n",
      "    fontname = \"system-ui\";\n",
      if options[:theme] == :dark do
        [
          "    fontcolor = \"#e5e7eb\";\n",
          "    color = \"#d1d5db\";\n"
        ]
      end,
      "  ];\n",
      "  rankdir = LR;\n",
      graph |> render_graph() |> indent(),
      graph |> render_edges() |> indent(),
      "}\n"
    ]
  end

  @spec render_graph(graph :: :digraph.graph()) :: iodata()
  defp render_graph(graph) do
    graph
    |> :digraph.vertices()
    |> Enum.reject(fn
      %Vertex.Root{} -> true
      %Vertex.Content{} -> true
      _ -> false
    end)
    |> Enum.map(&{Vertex.graph_group(&1), &1})
    |> render_grouped_vertices()
  end

  @spec render_grouped_vertices(vertices :: [{[String.t()], Vertex.t()}]) :: iodata()
  defp render_grouped_vertices(vertices) do
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
      render_vertices(here[nil] || []),
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
          vertices |> render_grouped_vertices() |> indent(),
          "}\n"
        ]
      end
    ]
  end

  @spec render_vertices(vertices :: [Vertex.t()]) :: iodata()
  defp render_vertices(vertices) do
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
        "\"];\n"
      ]
    end
  end

  @spec render_edges(graph :: :digraph.graph()) :: iodata()
  defp render_edges(graph) do
    for edge <- :digraph.edges(graph),
        {_, from, to, label} = :digraph.edge(graph, edge),
        label != :content,
        not match?(%Vertex.Root{}, from),
        not match?(%Vertex.Root{}, to) do
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
