defmodule Clarity.TooltipComponent do
  @moduledoc """
  A lazy-loading tooltip component that only renders tooltips for visible and nearby vertices.

  This component uses LiveView streams to efficiently manage tooltips, initially rendering
  only tooltips for breadcrumb vertices and their neighbors, then loading additional tooltips
  on demand as users hover over elements.
  """

  use Clarity.Web, :live_component

  import Clarity.Components.MarkdownComponent, only: [markdown: 1]

  alias Clarity.Graph
  alias Clarity.Vertex

  @impl Phoenix.LiveComponent
  def mount(socket) do
    socket = stream_configure(socket, :tooltips, dom_id: &"tooltip-#{Vertex.id(&1)}")
    {:ok, stream(socket, :tooltips, [])}
  end

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    preload_vertices = compute_preload_vertices(socket.assigns)

    {:ok, stream(socket, :tooltips, preload_vertices, reset: true)}
  end

  @impl Phoenix.LiveComponent
  def handle_event("load_tooltip", %{"vertex_id" => "tooltip-" <> vertex_id}, socket) do
    vertex = Graph.get_vertex(socket.assigns.graph, vertex_id)

    if vertex && has_tooltip?(vertex) do
      {:reply, %{"added" => true}, stream_insert(socket, :tooltips, vertex)}
    else
      {:reply, %{"added" => false}, socket}
    end
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="tooltips-container" phx-update="stream" phx-hook="Tooltip">
      <div id="tooltip-placeholder" class="tooltip hidden py-5">
        <div class="border border-base-light-400 dark:border-base-dark-600 shadow-lg bg-white dark:bg-base-dark-800 text-gray-900 dark:text-base-dark-100 px-4 py-2 rounded-xs">
          <.loading_spinner />
        </div>
      </div>
      <div
        :for={{dom_id, vertex} <- @streams.tooltips}
        id={dom_id}
        class="tooltip hidden py-5"
      >
        <div class="border border-base-light-400 dark:border-base-dark-600 shadow-lg bg-white dark:bg-base-dark-800 text-gray-900 dark:text-base-dark-100 px-4 py-2 rounded-xs">
          <.markdown content={get_tooltip_content(vertex)} prefix={@prefix} lens={@lens} />
        </div>
      </div>
    </div>
    """
  end

  @spec compute_preload_vertices(map()) :: [Vertex.t()]
  defp compute_preload_vertices(assigns) do
    breadcrumb_vertices = assigns.breadcrumbs

    neighbor_vertices =
      Enum.flat_map(breadcrumb_vertices, fn vertex ->
        in_neighbors = Graph.in_neighbors(assigns.graph, vertex)
        out_neighbors = Graph.out_neighbors(assigns.graph, vertex)
        in_neighbors ++ out_neighbors
      end)

    (breadcrumb_vertices ++ neighbor_vertices)
    |> Enum.uniq()
    |> Enum.filter(&has_tooltip?/1)
  end

  @spec has_tooltip?(Vertex.t()) :: boolean()
  defp has_tooltip?(vertex) do
    tooltip = Vertex.TooltipProvider.tooltip(vertex)
    tooltip != nil && String.trim(IO.iodata_to_binary(tooltip)) != ""
  end

  @spec get_tooltip_content(Vertex.t()) :: String.t()
  defp get_tooltip_content(vertex) do
    vertex
    |> Vertex.TooltipProvider.tooltip()
    |> IO.iodata_to_binary()
    |> String.trim()
  end
end
