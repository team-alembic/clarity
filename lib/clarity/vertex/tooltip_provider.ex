defprotocol Clarity.Vertex.TooltipProvider do
  @moduledoc """
  Protocol for providing tooltip content for vertices.

  This protocol allows vertices to specify their tooltip content,
  which is displayed when hovering over the vertex in graph visualizations.

  Note: This component is rendered for every vertex in the graph, so it
  should be efficient.
  """

  @fallback_to_any true

  @doc """
  Returns the tooltip content for this vertex.

  Returns iodata that will be rendered as markdown, or nil if no tooltip
  should be displayed.
  """
  @spec tooltip(t()) :: iodata() | nil
  def tooltip(vertex)
end

defimpl Clarity.Vertex.TooltipProvider, for: Any do
  @moduledoc false

  @impl Clarity.Vertex.TooltipProvider
  def tooltip(_vertex), do: nil
end
