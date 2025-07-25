defprotocol AshAtlas.Tree.Node do
  @moduledoc """
  Protocol for AshAtlas tree nodes.
  """

  @spec unique_id(t) :: String.t()
  def unique_id(node)

  @spec graph_id(t) :: iodata()
  def graph_id(node)

  @spec graph_group(t) :: [iodata()]
  def graph_group(node)

  @spec type_label(t) :: String.t()
  def type_label(node)

  @spec render_name(t) :: String.t()
  def render_name(node)

  @spec dot_shape(t) :: String.t()
  def dot_shape(node)
end
