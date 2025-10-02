defprotocol Clarity.Vertex.GraphGroupProvider do
  @moduledoc """
  Protocol for providing graph group information for vertices.

  This protocol allows vertices to specify which group they belong to in
  graph visualizations, which is used for organizing and grouping related
  vertices together.
  """

  @fallback_to_any true

  @doc """
  Returns the group to which the vertex belongs in the graph.

  This is used for grouping vertices in the visualization.
  Returns a list of iodata representing the group hierarchy.
  """
  @spec graph_group(t()) :: [iodata()]
  def graph_group(vertex)
end

defimpl Clarity.Vertex.GraphGroupProvider, for: Any do
  @moduledoc false

  @impl Clarity.Vertex.GraphGroupProvider
  def graph_group(_vertex), do: []
end
