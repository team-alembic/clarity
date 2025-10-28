defmodule Clarity.Content.Graph do
  @moduledoc """
  Built-in content provider for graph visualization.

  This content provider displays the graph navigation view and is shown for all vertices.
  It uses Graphviz DOT format to render the current subgraph with zoom controls.
  """

  @behaviour Clarity.Content

  use Clarity.Web, :live_component

  alias Clarity.Graph

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
  def mount(socket) do
    {:ok, assign(socket, max_vertices: 50, show_controls: false)}
  end

  @impl Phoenix.LiveComponent
  def update(params, socket) do
    socket = assign(socket, params)

    {:ok, socket}
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

    zoom_level = {outgoing_edges, incoming_edges}

    if socket.assigns.zoom_level != zoom_level do
      send(
        self(),
        {:update_zoom_level, {outgoing_edges, incoming_edges}}
      )
    end

    {:noreply, assign(socket, max_vertices: max_vertices)}
  end
end
