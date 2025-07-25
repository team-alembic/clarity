defmodule AshAtlas.Graph do
  alias AshAtlas.Tree.Node

  import Phoenix.HTML

  @spec to_dot(graph :: :digraph.t()) :: iodata()
  def to_dot(graph) do
    [
      "digraph {\n",
      "  bgcolor = transparent;\n",
      "  fontname = \"system-ui\";\n",
      "  color = \"#9ca3af\";\n",
      "  fontcolor = \"#f0f0f0\";\n",
      "  node [\n",
      "    fontname = \"system-ui\";\n",
      "    fontcolor = \"#fff\";\n",
      "    style = filled;\n",
      "    fillcolor = \"#374151\";\n",
      "    color = \"#9ca3af\";\n",
      "  ];\n",
      "  edge [\n",
      "    fontname = \"system-ui\";\n",
      "    fontcolor = \"#e5e7eb\";\n",
      "    color = \"#d1d5db\";\n",
      "  ];\n",
      "  rankdir = LR;\n",
      render_nodes(graph) |> indent(),
      graph |> render_edges() |> indent(),
      "}\n"
    ]
  end

  defp render_nodes(graph) do
    graph
    |> :digraph.vertices()
    |> Enum.reject(fn
      %Node.Root{} -> true
      %Node.Content{} -> true
      _ -> false
    end)
    |> Enum.map(&{Node.graph_group(&1), &1})
    |> render_grouped_vertices()
  end

  defp render_grouped_vertices(vertices) do
    {here, nested} = vertices
    |> Enum.group_by(
      fn
        {[group | _rest], _node} -> group
        {[], _node} -> nil
      end,
      fn
        {[_group | rest], node} -> {rest, node}
        {[], node} -> node
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

  defp render_vertices(vertices) do
    for vertex <- vertices do
      [
        encode_node_id(vertex),
        " [label = ",
        escape_html_label([
          raw("<I><FONT POINT-SIZE=\"8\">"),
          Node.type_label(vertex),
          raw("</FONT></I><BR />"),
          Node.render_name(vertex)
        ]),
        ", shape = ",
        Node.dot_shape(vertex),
        ", URL = \"#",
        Node.unique_id(vertex),
        "\"];\n"
      ]
    end
  end

  defp render_edges(graph) do
    for edge <- :digraph.edges(graph),
        {_, from, to, label} = :digraph.edge(graph, edge),
        label != :content,
        not match?(%Node.Root{}, from),
        not match?(%Node.Root{}, to) do
      [
        encode_node_id(from),
        " -> ",
        encode_node_id(to),
        ";\n"
        # TODO: Show label?
        # " [label = \"",
        # escape_html_label(label),
        # "\"];\n"
      ]
    end
  end

  defp indent(content) do
    content
    |> IO.iodata_to_binary()
    |> String.split("\n")
    |> Enum.map(&(["\n  ", &1]))
  end

  @spec encode_node_id(node :: Node.t()) :: iodata()
  defp encode_node_id(%node_module{} = node) do
    encode_id([inspect(node_module), "_", node |> Node.graph_id() |> to_string()])
  end

  @spec encode_id(id :: iodata()) :: iodata()
  defp encode_id(id) do
    {:safe, content} = id |> to_string() |> html_escape()
    [?<, content, ?>]
  end

  @spec escape_html_label(text :: iodata()) :: iodata()
  defp escape_html_label(text) do
    [?<, Phoenix.HTML.Safe.to_iodata(text), ?>]
  end
end
