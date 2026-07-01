defmodule Clarity.Perspective.Lens do
  @moduledoc """
  Data structure representing a lens that provides a specific view onto the graph.

  A lens filters the graph to a subset relevant for a certain audience and defines
  how that filtered view should be presented, including the starting vertex and
  default content ordering.
  """

  alias Clarity.Content
  alias Clarity.Graph
  alias Clarity.Status

  @type icon_fn() :: (-> Phoenix.LiveView.Rendered.t())
  @type content_sorter_fn() :: (Content.t(), Content.t() -> boolean())
  @type show_vertex_types_fn() :: ([module()] -> [module()])
  @type status_filter_fn() :: (Status.t() -> boolean())

  @type t() :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          description: String.t() | nil,
          icon: icon_fn(),
          filter: Graph.Filter.filter(),
          content_sorter: content_sorter_fn(),
          show_vertex_types: show_vertex_types_fn(),
          status_filter: status_filter_fn()
        }

  @enforce_keys [:id, :name, :icon, :filter]
  defstruct [
    :id,
    :name,
    :description,
    :icon,
    :filter,
    content_sorter: &__MODULE__.sort_alphabetically/2,
    show_vertex_types: &__MODULE__.default_show_vertex_types/1,
    status_filter: &__MODULE__.reject_all_statuses/1
  ]

  @doc """
  Default content sorter that sorts by priority, then alphabetically by name,
  then by id for deterministic ordering.

  This is the default sorting function used by lenses unless they specify
  their own content_sorter function. Content providers can implement the
  `sort_priority/0` callback to control their position (lower values first).
  """
  @spec sort_alphabetically(Content.t(), Content.t()) :: boolean()
  def sort_alphabetically(a, b) do
    cond do
      a.sort_priority != b.sort_priority -> a.sort_priority < b.sort_priority
      a.name != b.name -> a.name <= b.name
      true -> a.id <= b.id
    end
  end

  @doc """
  Default vertex type filter that shows all vertex types.

  This is the default function used by lenses unless they specify
  their own show_vertex_types function. Returns all types unchanged.
  """
  @spec default_show_vertex_types([module()]) :: [module()]
  def default_show_vertex_types(types), do: types

  @doc """
  Default status filter that surfaces no statuses.

  Status indicators are opt-in per lens: a lens shows none unless it provides its
  own `status_filter`, typically selecting the status `class`es it cares about
  (e.g. `&(&1.class in [:security, :hygiene])`).
  """
  @spec reject_all_statuses(Status.t()) :: boolean()
  def reject_all_statuses(_status), do: false
end
