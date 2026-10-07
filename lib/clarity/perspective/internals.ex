defmodule Clarity.Perspective.Internals do
  @moduledoc """
  Vertices a framework creates for its own use, which say little about the
  application being explored.

  So far these are the two `ShadowDomain` modules Ash defines for itself, for
  embedded types and filters, which hold no resources.

  Unless a lens sets `show_internals?` (only the Debug lens does), they are
  removed before it filters the graph, so it treats them as absent: an
  application shown only for its internals, such as `ash` in the Architect
  lens, goes with them.
  """

  alias Clarity.Graph
  alias Clarity.Vertex

  @doc """
  Returns whether `vertex` is a framework internal.
  """
  @spec internal?(Vertex.t()) :: boolean()
  # Matched by name: the vertex module only exists when Ash is loaded.
  def internal?(%{__struct__: Vertex.Ash.Domain, domain: domain}),
    do: Application.get_application(domain) == :ash

  def internal?(_vertex), do: false

  @doc """
  Returns the ids of the framework internals in `graph`.
  """
  @spec ids(Graph.t()) :: [String.t()]
  def ids(graph) do
    for vertex <- Graph.vertices(graph), internal?(vertex), do: Vertex.id(vertex)
  end
end
