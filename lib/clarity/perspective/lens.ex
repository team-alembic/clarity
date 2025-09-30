defmodule Clarity.Perspective.Lens do
  @moduledoc """
  Data structure representing a lens that provides a specific view onto the graph.

  A lens filters the graph to a subset relevant for a certain audience and defines
  how that filtered view should be presented, including the starting vertex and
  default content ordering.
  """

  alias Clarity.Graph
  alias Clarity.Vertex
  alias Clarity.Vertex.Content
  alias Clarity.Vertex.Root

  @type icon_fn() :: (-> Phoenix.LiveView.Rendered.t())
  @type intro_vertex_fn() :: (Graph.t() -> Vertex.t() | nil)
  @type content_sorter_fn() :: (Content.t(), Content.t() -> boolean())

  @type t() :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          description: String.t() | nil,
          icon: icon_fn(),
          filter: Graph.Filter.filter_fn(),
          content_sorter: content_sorter_fn(),
          intro_vertex: intro_vertex_fn()
        }

  @enforce_keys [:id, :name, :icon, :filter]
  defstruct [
    :id,
    :name,
    :description,
    :icon,
    :filter,
    content_sorter: &__MODULE__.sort_alphabetically_by_id/2,
    intro_vertex: &__MODULE__.default_intro_vertex/1
  ]

  @doc """
  Default content sorter that sorts alphabetically by content ID.

  This is the default sorting function used by lenses unless they specify
  their own content_sorter function.
  """
  @spec sort_alphabetically_by_id(Content.t(), Content.t()) :: boolean()
  def sort_alphabetically_by_id(a, b), do: a.id <= b.id

  @doc """
  Default intro vertex function that returns the root vertex.

  This is the default intro vertex function used by lenses unless they specify
  their own intro_vertex function.
  """
  @spec default_intro_vertex(Graph.t()) :: Root.t()
  def default_intro_vertex(_graph), do: %Root{}
end
