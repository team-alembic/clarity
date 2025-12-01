defmodule Clarity.TreeComponent do
  @moduledoc """
  A lazy-loading navigation tree component that only renders visible nodes.

  This component maintains user-opened branches across graph updates and only
  renders nodes that are visible (root, breadcrumb path, and user-opened branches).
  """

  use Clarity.Web, :live_component

  alias Clarity.Graph
  alias Clarity.Perspective.Lens
  alias Clarity.Vertex
  alias Phoenix.LiveView.Rendered

  embed_templates "tree_component/*"

  @impl Phoenix.LiveComponent
  def mount(socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    visible_ids = compute_visible_ids(socket.assigns)

    {:ok, assign(socket, visible_ids: visible_ids)}
  end

  @impl Phoenix.LiveComponent
  def handle_event("toggle", %{"vertex_id" => vertex_id}, socket) do
    opened =
      if MapSet.member?(socket.assigns.opened, vertex_id) do
        MapSet.delete(socket.assigns.opened, vertex_id)
      else
        MapSet.put(socket.assigns.opened, vertex_id)
      end

    visible_ids = compute_visible_ids(%{socket.assigns | opened: opened})

    # Notify parent to persist the opened state
    send(self(), {:update_tree_opened, opened})

    {:noreply, assign(socket, opened: opened, visible_ids: visible_ids)}
  end

  attr :graph, :any, required: true
  attr :vertex, :any, required: true
  attr :visible_ids, :any, required: true
  attr :active_vertex, :any, required: true
  attr :prefix, :string, required: true
  attr :lens, Lens, required: true
  attr :myself, :any, required: true

  @spec render_vertex(map()) :: Rendered.t()
  def render_vertex(assigns)

  attr :graph, :any, required: true
  attr :vertex, :any, required: true
  attr :visible_ids, :any, required: true
  attr :active_vertex, :any, required: true
  attr :prefix, :string, required: true
  attr :lens, Lens, required: true
  attr :myself, :any, required: true
  attr :any_sibling_has_children, :boolean, required: true

  @spec render_node(map()) :: Rendered.t()
  def render_node(assigns)

  @spec compute_visible_ids(map()) :: MapSet.t()
  defp compute_visible_ids(assigns) do
    breadcrumb_ids = MapSet.new(assigns.breadcrumbs, &Vertex.id/1)

    MapSet.union(breadcrumb_ids, assigns.opened)
  end

  @spec has_children?(Graph.t(), Vertex.t()) :: boolean()
  defp has_children?(graph, vertex) do
    children = Graph.navigation_children(graph, vertex)
    Enum.any?(children, fn {label, vertices} -> label != :content and vertices != [] end)
  end

  @spec open?(Vertex.t(), MapSet.t()) :: boolean()
  defp open?(vertex, visible_ids) do
    MapSet.member?(visible_ids, Vertex.id(vertex))
  end
end
