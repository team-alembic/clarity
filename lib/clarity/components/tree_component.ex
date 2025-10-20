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

  @impl Phoenix.LiveComponent
  def mount(socket) do
    {:ok, assign(socket, opened: MapSet.new())}
  end

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    visible_ids = compute_visible_ids(socket.assigns)

    {:ok, assign(socket, visible_ids: visible_ids)}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div>
      <.render_vertex
        graph={@graph}
        vertex={%Clarity.Vertex.Root{}}
        visible_ids={@visible_ids}
        active_vertex={@active_vertex}
        prefix={@prefix}
        lens={@lens}
        myself={@myself}
      />
    </div>
    """
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
  defp render_vertex(assigns) do
    ~H"""
    <%= for {label, children} <- Graph.navigation_children(@graph, @vertex), label != :content do %>
      <div>
        <span class="cursor-pointer select-none text-base-light-600 dark:text-base-dark-400 hover:text-primary-light dark:hover:text-primary-dark px-2 py-1 rounded-xs group-open:bg-base-light-200 dark:group-open:bg-base-dark-700 transition-colors">
          {label}
        </span>
        <ul class="border-l border-base-light-300 dark:border-base-dark-700 pl-2 space-y-1">
          <li :for={child <- children}>
            <.render_node
              graph={@graph}
              vertex={child}
              visible_ids={@visible_ids}
              active_vertex={@active_vertex}
              prefix={@prefix}
              lens={@lens}
              myself={@myself}
              any_sibling_has_children={Enum.any?(children, &has_children?(@graph, &1))}
            />
          </li>
        </ul>
      </div>
    <% end %>
    """
  end

  attr :graph, :any, required: true
  attr :vertex, :any, required: true
  attr :visible_ids, :any, required: true
  attr :active_vertex, :any, required: true
  attr :prefix, :string, required: true
  attr :lens, Lens, required: true
  attr :myself, :any, required: true
  attr :any_sibling_has_children, :boolean, required: true

  @spec render_node(map()) :: Rendered.t()
  defp render_node(assigns) do
    ~H"""
    <%= if has_children?(@graph, @vertex) do %>
      <details
        id={"tree-node-#{Vertex.id(@vertex)}"}
        open={open?(@vertex, @visible_ids)}
        phx-hook="Details"
        phx-toggle="toggle"
        phx-value-vertex_id={Vertex.id(@vertex)}
        phx-target={@myself}
      >
        <summary>
          <.link
            patch={Path.join([@prefix, @lens.id, Vertex.id(@vertex)])}
            class={
              "inline px-2 py-1 rounded-xs hover:bg-base-light-200 dark:hover:bg-base-dark-700 hover:text-primary-light dark:hover:text-primary-dark transition-colors font-medium" <>
              if @vertex == @active_vertex, do: " bg-primary-light dark:bg-primary-dark text-white dark:text-base-dark-900", else: ""
            }
          >
            <.vertex_name vertex={@vertex} />
          </.link>
        </summary>
        <%= if open?(@vertex, @visible_ids) do %>
          <div class="ml-4 group">
            <.render_vertex
              graph={@graph}
              vertex={@vertex}
              visible_ids={@visible_ids}
              active_vertex={@active_vertex}
              prefix={@prefix}
              lens={@lens}
              myself={@myself}
            />
          </div>
        <% else %>
          <.loading_spinner class="ml-4 py-2" />
        <% end %>
      </details>
    <% else %>
      <.link
        patch={Path.join([@prefix, @lens.id, Vertex.id(@vertex)])}
        class={[
          "inline px-2 py-1 rounded-xs hover:bg-base-light-200 dark:hover:bg-base-dark-700 hover:text-primary-light dark:hover:text-primary-dark transition-colors font-medium",
          @any_sibling_has_children && "pl-[25px]",
          @vertex == @active_vertex &&
            "bg-primary-light dark:bg-primary-dark text-white dark:text-base-dark-900"
        ]}
      >
        <.vertex_name vertex={@vertex} />
      </.link>
    <% end %>
    """
  end

  attr :vertex, :any, required: true

  @spec vertex_name(map()) :: Rendered.t()
  defp vertex_name(assigns) do
    ~H"""
    <span data-tooltip={"tooltip-#{Vertex.id(@vertex)}"}>{Vertex.name(@vertex)}</span>
    """
  end

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
