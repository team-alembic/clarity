defmodule Clarity.Content.Graph do
  @moduledoc """
  Built-in content provider for graph visualization.

  This content provider displays the graph navigation view and is shown for all vertices.
  It uses Graphviz DOT format to render the current subgraph with zoom controls.
  """

  @behaviour Clarity.Content

  alias Clarity.Graph

  @impl Clarity.Content
  def name, do: "Graph Navigation"

  @impl Clarity.Content
  def description, do: "Visual graph navigation and exploration"

  @impl Clarity.Content
  def applies?(_vertex, _lens), do: true

  @impl Clarity.Content
  def render_static(vertex, _lens) do
    {:viz,
     fn %{theme: theme, zoom_subgraph: zoom_subgraph} ->
       Graph.DOT.to_dot(
         zoom_subgraph,
         theme: theme,
         highlight: vertex
       )
     end}
  end
end
