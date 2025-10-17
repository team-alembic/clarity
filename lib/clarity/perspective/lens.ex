defmodule Clarity.Perspective.Lens do
  @moduledoc """
  Data structure representing a lens that provides a specific view onto the graph.

  A lens filters the graph to a subset relevant for a certain audience and defines
  how that filtered view should be presented, including the starting vertex and
  default content ordering.
  """

  alias Clarity.Content
  alias Clarity.Graph

  @type icon_fn() :: (-> Phoenix.LiveView.Rendered.t())
  @type content_sorter_fn() :: (Content.t(), Content.t() -> boolean())

  @type t() :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          description: String.t() | nil,
          icon: icon_fn(),
          filter: Graph.Filter.filter_fn(),
          content_sorter: content_sorter_fn()
        }

  @enforce_keys [:id, :name, :icon, :filter]
  defstruct [
    :id,
    :name,
    :description,
    :icon,
    :filter,
    content_sorter: &__MODULE__.sort_alphabetically/2
  ]

  @doc """
  Default content sorter that sorts alphabetically by content name, with Graph deprioritized.

  This is the default sorting function used by lenses unless they specify
  their own content_sorter function. Graph content is moved to the end.
  """
  @spec sort_alphabetically(Content.t(), Content.t()) :: boolean()
  def sort_alphabetically(a, b)
  def sort_alphabetically(%Content{provider: Content.Graph}, _b), do: false
  def sort_alphabetically(_a, %Content{provider: Content.Graph}), do: true
  def sort_alphabetically(a, b), do: a.name <= b.name
end
