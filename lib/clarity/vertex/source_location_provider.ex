defprotocol Clarity.Vertex.SourceLocationProvider do
  @moduledoc """
  Protocol for providing source location information for vertices.

  This protocol allows vertices to specify their source file location,
  which can be used for navigation and debugging purposes.
  """

  @fallback_to_any true

  @doc """
  Returns the source location for this vertex, or nil if no location is available.
  """
  @spec source_location(t()) :: Clarity.SourceLocation.t() | nil
  def source_location(vertex)
end

defimpl Clarity.Vertex.SourceLocationProvider, for: Any do
  @moduledoc false

  @impl Clarity.Vertex.SourceLocationProvider
  def source_location(_vertex), do: nil
end
