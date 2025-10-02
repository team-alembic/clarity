defprotocol Clarity.Vertex.GraphShapeProvider do
  @moduledoc """
  Protocol for providing graph shape information for vertices.

  This protocol allows vertices to specify their visual shape in graph
  visualizations using Graphviz DOT notation.
  """

  @fallback_to_any true

  @doc """
  Returns the shape to be used for the vertex in graph visualization.

  This is used to determine how the vertex will be rendered in the graph
  using Graphviz DOT shape names (e.g., "box", "circle", "component").
  """
  @spec shape(t()) :: String.t()
  def shape(vertex)
end

defimpl Clarity.Vertex.GraphShapeProvider, for: Any do
  @moduledoc false

  @impl Clarity.Vertex.GraphShapeProvider
  def shape(_vertex), do: "box"
end
