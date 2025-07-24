defmodule AshAtlas.Graph do
  alias AshAtlas.Tree.Node

  @spec to_dot(:digraph.t()) :: iodata()
  def to_dot(graph) do
    # 1) Partition every vertex into a map %{module => [nodes]}
    clusters =
      :digraph.vertices(graph)
      |> Enum.group_by(fn %mod{} -> mod end)
      |> Map.delete(Node.Root)
      |> Map.delete(Node.Content)

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

      # 2) Emit a Graphviz “cluster” per module
      for {mod, nodes} <- clusters do
        cluster_name =
          mod
          |> Macro.underscore()
          |> String.replace(~r/[^a-z0-9_]/, "")
          |> then(&"cluster_#{&1}")

        [
          "  subgraph #{cluster_name} {\n",
          "    label = \"#{inspect(mod)}\";\n",
          "    style = rounded;\n",
          for node <- nodes do
            "    #{Node.graph_id(node)} " <>
              "[label = #{inspect(Node.render_name(node))}, " <>
              "shape = #{Node.dot_shape(node)}, " <>
              "URL   = #{inspect("#" <> Node.unique_id(node))}];\n"
          end,
          "  }\n"
        ]
      end,

      # 3) Emit edges **without** labels
      for edge <- :digraph.edges(graph),
          {_, from, to, label} = :digraph.edge(graph, edge),
          label != :content,
          not match?(%Node.Root{}, from),
          not match?(%Node.Root{}, to) do
        "  #{Node.graph_id(from)} -> #{Node.graph_id(to)};\n"
      end,
      "}\n"
    ]
  end
end
