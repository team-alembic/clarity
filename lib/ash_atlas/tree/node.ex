defprotocol AshAtlas.Tree.Node do
  @moduledoc """
  Protocol for AshAtlas tree nodes.
  """

  def unique_id(node)

  def graph_id(node)

  def render_name(node)

  def dot_shape(node)
end
