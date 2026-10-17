defmodule Clarity.Perspective.Internals do
  @moduledoc """
  Vertices a framework creates for its own use, which say little about the
  application being explored.

  So far these are the two `ShadowDomain` modules Ash defines for itself, for
  embedded types and filters, which hold no resources, and the modules Ash
  generates for signals (`Ash.Signals.Index.*`, `Ash.Signals.Listeners.*` and
  `Ash.Signals.Dispatch.*`).

  Unless a lens sets `show_internals?` (only the Debug lens does), they are
  removed before it filters the graph, so it treats them as absent: an
  application shown only for its internals, such as `ash` in the Architect
  lens, goes with them.
  """

  alias Clarity.Graph
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Domain

  @doc """
  Returns whether `vertex` is a framework internal.
  """
  @spec internal?(Vertex.t()) :: boolean()
  # Matched by name: the vertex module only exists when Ash is loaded.
  def internal?(%{__struct__: Domain, domain: domain}),
    do: Clarity.Config.application_of(domain) == :ash

  def internal?(%Vertex.Module{module: module}), do: generated_for_signals?(module)

  def internal?(_vertex), do: false

  @doc """
  Returns the ids of the framework internals in `graph`.
  """
  @spec ids(Graph.t()) :: [String.t()]
  def ids(graph) do
    for type <- [Domain, Vertex.Module],
        vertex <- Graph.vertices(graph, {:==, :vertex_type, type}),
        internal?(vertex),
        do: Vertex.id(vertex)
  end

  @spec generated_for_signals?(module()) :: boolean()
  defp generated_for_signals?(module) do
    String.starts_with?(Atom.to_string(module), [
      "Elixir.Ash.Signals.Index.",
      "Elixir.Ash.Signals.Listeners.",
      "Elixir.Ash.Signals.Dispatch."
    ])
  end
end
