defmodule Clarity.Content.Graph do
  @moduledoc """
  Built-in content provider for graph visualization.

  This content provider displays the graph navigation view and is shown for all vertices.
  It uses Graphviz DOT format to render the current subgraph with zoom controls.
  """

  @behaviour Clarity.Content

  use Clarity.Web, :live_component

  alias Clarity.Graph
  alias Clarity.Perspective
  alias Phoenix.LiveView.Socket

  @impl Clarity.Content
  def name, do: "Graph Navigation"

  @impl Clarity.Content
  def description, do: "Visual graph navigation and exploration"

  @impl Clarity.Content
  def applies?(_vertex, _lens), do: true

  @impl Clarity.Content
  def render_static(vertex, _lens) do
    {:viz,
     fn %{theme: theme, zoom_subgraph: zoom_subgraph} ->
       Graph.DOT.to_dot(
         zoom_subgraph,
         theme: theme,
         highlight: vertex,
         max_vertices: 50
       )
     end}
  end

  @impl Phoenix.LiveComponent
  def update(params, socket) do
    socket = assign(socket, params)

    {outgoing_edges, incoming_edges} = Perspective.get_zoom(socket.assigns.perspective_pid)

    socket =
      socket
      |> assign(
        outgoing_edges: outgoing_edges,
        incoming_edges: incoming_edges,
        show_controls: false,
        max_vertices: 50
      )
      |> reload_graph()

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div class="content flex flex-col h-full relative">
      <div class="absolute top-4 right-4 z-10">
        <button
          type="button"
          phx-click="toggle_controls"
          phx-target={@myself}
          class="inline-flex items-center justify-center p-2 rounded-md text-base-light-600 dark:text-base-dark-400 hover:text-base-light-900 dark:hover:text-base-dark-100 bg-base-light-100 dark:bg-base-dark-800 hover:bg-base-light-200 dark:hover:bg-base-dark-700 focus:outline-hidden focus:ring-2 focus:ring-primary-light dark:focus:ring-primary-dark transition-colors shadow-md border border-base-light-300 dark:border-base-dark-700"
          aria-label="Toggle zoom controls"
        >
          <svg
            class="w-5 h-5"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
            xmlns="http://www.w3.org/2000/svg"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4"
            />
          </svg>
        </button>
        <div
          :if={@show_controls}
          class="absolute top-12 right-0 bg-base-light-100 dark:bg-base-dark-800 rounded-lg p-4 shadow-lg border border-base-light-300 dark:border-base-dark-700 min-w-[20rem]"
        >
          <h3 class="text-sm font-semibold text-base-light-900 dark:text-base-dark-50 mb-3">
            Graph Controls
          </h3>
          <form phx-change="update_controls" phx-target={@myself} class="flex flex-col gap-4">
            <div class="flex flex-col gap-2">
              <div class="flex items-center justify-between">
                <span class="text-sm font-medium text-base-light-700 dark:text-base-dark-300">
                  Outgoing:
                </span>
                <span class="text-sm font-semibold text-base-light-900 dark:text-base-dark-100 min-w-[1.5rem] text-right">
                  {@outgoing_edges}
                </span>
              </div>
              <input
                type="range"
                name="outgoing_edges"
                value={@outgoing_edges}
                min="0"
                max="5"
                class="w-full h-2 bg-base-light-300 dark:bg-base-dark-600 rounded-lg appearance-none cursor-pointer accent-primary-light dark:accent-primary-dark"
              />
            </div>
            <div class="flex flex-col gap-2">
              <div class="flex items-center justify-between">
                <span class="text-sm font-medium text-base-light-700 dark:text-base-dark-300">
                  Incoming:
                </span>
                <span class="text-sm font-semibold text-base-light-900 dark:text-base-dark-100 min-w-[1.5rem] text-right">
                  {@incoming_edges}
                </span>
              </div>
              <input
                type="range"
                name="incoming_edges"
                value={@incoming_edges}
                min="0"
                max="5"
                class="w-full h-2 bg-base-light-300 dark:bg-base-dark-600 rounded-lg appearance-none cursor-pointer accent-primary-light dark:accent-primary-dark"
              />
            </div>
            <div class="flex flex-col gap-2">
              <label class="flex items-center justify-between">
                <span class="text-sm font-medium text-base-light-700 dark:text-base-dark-300">
                  Max Vertices:
                </span>
                <input
                  type="number"
                  name="max_vertices"
                  value={@max_vertices}
                  min="1"
                  max="1000"
                  class="w-20 px-3 py-1 text-sm bg-base-light-50 dark:bg-base-dark-900 border border-base-light-300 dark:border-base-dark-600 rounded-md text-base-light-900 dark:text-base-dark-100 focus:outline-hidden focus:ring-2 focus:ring-primary-light dark:focus:ring-primary-dark focus:border-transparent transition-colors hover:border-base-light-400 dark:hover:border-base-dark-500"
                />
              </label>
            </div>
          </form>
        </div>
      </div>
      <div class="flex-1 min-h-0 p-4">
        <.viz graph={@dot_graph} id="content-view-viz" class="h-full" />
      </div>
    </div>
    """
  end

  @impl Phoenix.LiveComponent
  def handle_event("toggle_controls", _params, socket) do
    {:noreply, assign(socket, show_controls: !socket.assigns.show_controls)}
  end

  @impl Phoenix.LiveComponent
  def handle_event(
        "update_controls",
        %{"outgoing_edges" => out_str, "incoming_edges" => in_str, "max_vertices" => max_str},
        socket
      ) do
    {outgoing_edges, _} = Integer.parse(out_str)
    {incoming_edges, _} = Integer.parse(in_str)
    {max_vertices, _} = Integer.parse(max_str)

    max_vertices = max(1, min(max_vertices, 1000))

    :ok = Perspective.set_zoom(socket.assigns.perspective_pid, {outgoing_edges, incoming_edges})

    {:noreply,
     socket
     |> assign(
       outgoing_edges: outgoing_edges,
       incoming_edges: incoming_edges,
       max_vertices: max_vertices
     )
     |> reload_graph()}
  end

  @spec reload_graph(Socket.t()) :: Socket.t()
  defp reload_graph(socket) do
    zoom_subgraph = Perspective.get_zoom_subgraph(socket.assigns.perspective_pid)

    dot_graph =
      Graph.DOT.to_dot(zoom_subgraph,
        theme: socket.assigns.theme,
        highlight: socket.assigns.vertex,
        max_vertices: socket.assigns.max_vertices
      )

    assign(socket, zoom_subgraph: zoom_subgraph, dot_graph: dot_graph)
  end
end
