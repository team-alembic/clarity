defprotocol Clarity.Vertex do
  @moduledoc """
  Protocol for vertices in the `Clarity` graph.
  """

  @doc """
  Returns a unique identifier for the vertex.

  Used for identifying vertices in the graph, including in the UI of the dashboard.

  ## Implementation

  Implementations should use `Clarity.Vertex.Util.id/2` to generate the ID:

      defimpl Clarity.Vertex do
        alias Clarity.Vertex.Util

        @impl Clarity.Vertex
        def id(vertex) do
          Util.id(@for, [identifying_parts])
        end
      end

  Where `@for` refers to the struct module being implemented for, and `identifying_parts`
  is a list of values that uniquely identify this vertex (e.g., module names, atoms, strings).
  """
  @spec id(t) :: String.t()
  def id(vertex)

  @doc """
  Returns the label for the type of the vertex.
  This is used for displaying the type of the vertex in the graph.
  """
  @spec type_label(t) :: String.t()
  def type_label(vertex)

  @doc """
  Returns the name of the vertex for display purposes.
  This is typically used in the UI to show the name of the vertex.
  """
  @spec name(t) :: String.t()
  def name(vertex)
end
