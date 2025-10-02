defprotocol Clarity.Vertex.ModuleProvider do
  @moduledoc """
  Protocol for extracting module atoms from vertices.

  This protocol allows vertices to specify which module should be used
  when displaying module documentation.
  """

  @fallback_to_any true

  @doc """
  Returns the module atom associated with this vertex, or nil if no module exists.
  """
  @spec module(t()) :: module() | nil
  def module(vertex)
end

defimpl Clarity.Vertex.ModuleProvider, for: Any do
  @moduledoc false

  @impl Clarity.Vertex.ModuleProvider
  def module(_vertex), do: nil
end
