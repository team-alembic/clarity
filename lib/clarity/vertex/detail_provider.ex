defprotocol Clarity.Vertex.DetailProvider do
  @moduledoc """
  Protocol for a short detail shown, muted, after a vertex's name in the
  navigation tree.

  Use it for the one thing that tells a vertex apart from its siblings at a
  glance but would crowd its name: a policy's rule, say, after the actions it
  covers. Keep it to a few words; the tree cuts long rows short.
  """

  @fallback_to_any true

  @doc "Returns the detail, or `nil` for none."
  @spec detail(t()) :: String.t() | nil
  def detail(vertex)
end

defimpl Clarity.Vertex.DetailProvider, for: Any do
  @moduledoc false

  @impl Clarity.Vertex.DetailProvider
  def detail(_vertex), do: nil
end
