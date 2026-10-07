defprotocol Clarity.Vertex.TooltipProvider do
  @moduledoc """
  Protocol for providing tooltip content for vertices.

  `Clarity.Tooltip` turns this markdown into the hover hint shown for the
  vertex in the navigation tree, breadcrumbs and graph visualisations: the
  first prose paragraph becomes a one-line plain-text summary (see
  `Clarity.Tooltip.summarise/1`), so lead with a sentence describing the vertex.

  Note: This is called for every vertex rendered in the tree and graph, so it
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
