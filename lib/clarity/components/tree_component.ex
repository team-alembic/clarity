defmodule Clarity.TreeComponent do
  @moduledoc """
  A lazy-loading navigation tree component that only renders visible nodes.

  A node is open when it is on the breadcrumb path or the user expanded it,
  unless the user has collapsed it since the last navigation. The parent owns
  both sets so they survive graph updates, and clears the collapsed set when
  the path changes, revealing the newly current vertex.
  """

  use Clarity.Web, :live_component

  alias Clarity.Graph
  alias Clarity.Perspective.Lens
  alias Clarity.Status.Index
  alias Clarity.Tooltip
  alias Clarity.Vertex
  alias Phoenix.LiveView.Rendered
  alias Phoenix.LiveView.Socket

  embed_templates "tree_component/*"

  @impl Phoenix.LiveComponent
  def mount(socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    visible_ids = compute_visible_ids(socket.assigns)
    status_index = Index.build(socket.assigns.graph, socket.assigns.lens)

    {:ok, assign(socket, visible_ids: visible_ids, status_index: status_index)}
  end

  @impl Phoenix.LiveComponent
  def handle_event("toggle", %{"vertex_id" => vertex_id, "open" => true}, socket) do
    %{opened: opened, collapsed: collapsed} = socket.assigns

    set_tree_state(socket, MapSet.put(opened, vertex_id), MapSet.delete(collapsed, vertex_id))
  end

  def handle_event("toggle", %{"vertex_id" => vertex_id, "open" => false}, socket) do
    %{opened: opened, collapsed: collapsed} = socket.assigns

    set_tree_state(socket, MapSet.delete(opened, vertex_id), MapSet.put(collapsed, vertex_id))
  end

  @spec set_tree_state(Socket.t(), MapSet.t(), MapSet.t()) :: {:noreply, Socket.t()}
  defp set_tree_state(socket, opened, collapsed) do
    # Notify parent to persist the tree state
    send(self(), {:update_tree_state, opened, collapsed})

    socket = assign(socket, opened: opened, collapsed: collapsed)

    {:noreply, assign(socket, visible_ids: compute_visible_ids(socket.assigns))}
  end

  attr :graph, :any, required: true
  attr :vertex, :any, required: true
  attr :visible_ids, :any, required: true
  attr :active_vertex, :any, required: true
  attr :prefix, :string, required: true
  attr :lens, Lens, required: true
  attr :myself, :any, required: true
  attr :status_index, :any, required: true

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
  attr :status_index, :any, required: true

  @spec render_node(map()) :: Rendered.t()
  def render_node(assigns)

  attr :entry, :any, default: nil

  @doc false
  @spec status_badge(map()) :: Rendered.t()
  def status_badge(assigns) do
    ~H"""
    <%= if @entry do %>
      <span
        class={[
          "inline-flex shrink-0 items-center gap-1 ml-1.5 px-1.5 py-0.5 rounded-full align-middle",
          "text-xs font-medium leading-none ring-1 ring-inset",
          badge_classes(@entry.severity)
        ]}
        role="img"
        aria-label={badge_title(@entry)}
        {Tooltip.attrs(badge_title(@entry))}
      >
        <%= case @entry.severity do %>
          <% :error -> %>
            <.icon_error class="w-3 h-3" />
          <% :warning -> %>
            <.icon_warning class="w-3 h-3" />
          <% :info -> %>
            <.icon_info class="w-3 h-3" />
        <% end %>
        <span :if={@entry.count > 0} class="tabular-nums">{@entry.count}</span>
      </span>
    <% end %>
    """
  end

  @spec badge_classes(Clarity.Status.severity()) :: String.t()
  defp badge_classes(:error),
    do:
      "bg-red-100 text-red-700 ring-red-600/20 dark:bg-red-500/15 dark:text-red-300 dark:ring-red-400/30"

  defp badge_classes(:warning),
    do:
      "bg-yellow-100 text-yellow-800 ring-yellow-600/20 dark:bg-yellow-500/15 dark:text-yellow-300 dark:ring-yellow-400/30"

  defp badge_classes(:info),
    do:
      "bg-blue-100 text-blue-700 ring-blue-600/20 dark:bg-blue-500/15 dark:text-blue-300 dark:ring-blue-400/30"

  @spec badge_title(Index.entry()) :: String.t()
  defp badge_title(%{count: 0}), do: "flagged"

  defp badge_title(%{count: count}) do
    noun = if count == 1, do: "issue", else: "issues"
    "#{count} nested #{noun}"
  end

  @spec compute_visible_ids(map()) :: MapSet.t()
  defp compute_visible_ids(assigns) do
    breadcrumb_ids = MapSet.new(assigns.breadcrumbs, &Vertex.id/1)

    breadcrumb_ids
    |> MapSet.union(assigns.opened)
    |> MapSet.difference(assigns.collapsed)
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
