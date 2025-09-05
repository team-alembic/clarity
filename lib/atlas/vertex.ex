defprotocol Atlas.Vertex do
  @moduledoc """
  Protocol for vertices in the `Atlas` graph.
  """

  @doc """
  Returns a unique identifier for the vertex.

  Used for identifying vertexs in the graph, including in the UI of the dashboard.
  """
  @spec unique_id(t) :: String.t()
  def unique_id(vertex)

  @doc """
  Returns a graph ID for the vertex, which is used to identify the vertex in the
  graph.
  """
  @spec graph_id(t) :: iodata()
  def graph_id(vertex)

  @doc """
  Returns the group to which the vertex belongs in the graph.
  This is used for grouping vertexs in the visualization.
  """
  @spec graph_group(t) :: [iodata()]
  def graph_group(vertex)

  @doc """
  Returns the label for the type of the vertex.
  This is used for displaying the type of the vertex in the graph.
  """
  @spec type_label(t) :: String.t()
  def type_label(vertex)

  @doc """
  Renders the name of the vertex for display purposes.
  This is typically used in the UI to show the name of the vertex.
  """
  @spec render_name(t) :: String.t()
  def render_name(vertex)

  @doc """
  Returns the shape to be used for the vertex in the graph visualization.
  This is used to determine how the vertex will be rendered in the graph.
  """
  @spec dot_shape(t) :: String.t()
  def dot_shape(vertex)

  @doc """
  Returns the overview content for the vertex.

  Used for tooltips and other informational displays in the UI.

  Careful: This component is rendered for every vertex in the graph, so it
  should be efficient.
  """
  @spec markdown_overview(t) :: iodata() | nil
  def markdown_overview(vertex)
end
