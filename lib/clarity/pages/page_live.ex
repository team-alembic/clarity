defmodule Clarity.PageLive do
  @moduledoc false

  use Clarity.Web, :live_view

  alias Clarity.Content
  alias Clarity.Graph
  alias Clarity.Perspective.Internals
  alias Clarity.Perspective.Lens
  alias Clarity.Perspective.Lensmaker
  alias Clarity.Status
  alias Clarity.Tooltip
  alias Clarity.TreeComponent
  alias Clarity.Vertex
  alias Clarity.Vertex.Root
  alias Phoenix.LiveView.AsyncResult
  alias Phoenix.LiveView.Socket

  @impl Phoenix.LiveView
  def mount(params, session, socket) do
    if connected?(socket) do
      Clarity.subscribe(socket.assigns.clarity_pid, [:work_started, :work_completed])
      :timer.send_interval(100, :refresh)
    end

    initial_vertex = Map.get(session, "initial_vertex", "root")

    socket =
      socket
      |> assign(
        zoom_level: {1, 1},
        show_navigation: false,
        show_raw_drawer: false,
        tree_opened: MapSet.new(),
        tree_collapsed: MapSet.new(),
        # Short module names in the tree only; a candidate user preference.
        tree_name_style: :short,
        data: AsyncResult.loading(),
        page_title: "Loading...",
        shown_vertex_types: [],
        available_vertex_types: [],
        initial_vertex: initial_vertex
      )
      |> fetch_clarity()
      # LiveView forbids live patches during mount, which a live navigation to a
      # bare lens URL (e.g. from the lens switcher) would otherwise trigger.
      |> handle_routing(params, &push_navigate/2)

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _url, socket) do
    {:noreply, handle_routing(socket, params, &push_patch/2)}
  end

  @impl Phoenix.LiveView
  def handle_async(:data, {:ok, %{data: new_data}}, socket) do
    if socket.assigns.data.ok? do
      Graph.delete(socket.assigns.data.result.graph)
      Graph.delete(socket.assigns.data.result.zoom_graph)
    end

    {:noreply, assign(socket, data: AsyncResult.ok(new_data))}
  end

  def handle_async(:data, {:exit, reason}, socket), do: {:noreply, data_error(socket, reason)}

  @spec handle_routing(Socket.t(), map(), (Socket.t(), keyword() -> Socket.t())) :: Socket.t()
  defp handle_routing(socket, params, navigate_fn) do
    socket = assign(socket, params: params)

    case {params, socket.assigns.live_action} do
      {_params, :root} ->
        handle_root_route(socket, navigate_fn)

      {%{"lens" => lens_id}, :lens} ->
        handle_lens_route(lens_id, socket, navigate_fn)

      {%{"lens" => lens_id, "vertex" => vertex_id}, :vertex} ->
        handle_vertex_route(lens_id, vertex_id, socket, navigate_fn)

      {%{"lens" => lens_id, "vertex" => vertex_id, "content" => content_id}, :page} ->
        handle_page_route(lens_id, vertex_id, content_id, socket)
    end
  end

  @spec handle_root_route(Socket.t(), (Socket.t(), keyword() -> Socket.t())) :: Socket.t()
  defp handle_root_route(socket, navigate_fn) do
    default_lens_id = Clarity.Config.fetch_default_perspective_lens!()

    socket
    |> assign(:data, AsyncResult.loading(socket.assigns.data))
    |> navigate_fn.(to: Path.join([socket.assigns.prefix, default_lens_id]))
  end

  @spec handle_lens_route(String.t(), Socket.t(), (Socket.t(), keyword() -> Socket.t())) ::
          Socket.t()
  # Keeping the loaded data (marked as loading) leaves the current page on
  # screen until the lens's start page has loaded, rather than blanking it.
  defp handle_lens_route(lens_id, socket, navigate_fn) do
    socket
    |> assign(:data, AsyncResult.loading(socket.assigns.data))
    |> navigate_fn.(
      to: Path.join([socket.assigns.prefix, lens_id, socket.assigns.initial_vertex])
    )
  end

  @spec handle_vertex_route(String.t(), String.t(), Socket.t(), navigation_fn) :: Socket.t()
        when navigation_fn: (Socket.t(), keyword() -> Socket.t())
  defp handle_vertex_route(lens_id, vertex_id, socket, navigate_fn) do
    clarity = Clarity.get(socket.assigns.clarity_pid, :partial)

    with {:ok, lens} <- Lensmaker.get_lens_by_id(lens_id),
         vertex when not is_nil(vertex) <- Graph.get_vertex(clarity.graph, vertex_id) do
      contents = Content.get_contents_for_vertex(vertex, lens)
      first_content_id = get_first_content_id(contents)

      navigate_fn.(socket,
        to: Path.join([socket.assigns.prefix, lens.id, vertex_id, first_content_id])
      )
    else
      _ ->
        navigate_fn.(socket, to: Path.join([socket.assigns.prefix, lens_id, "root"]))
    end
  end

  @spec handle_page_route(String.t(), String.t(), String.t(), Socket.t()) :: Socket.t()
  defp handle_page_route(lens_id, vertex_id, content_id, socket) do
    socket = fetch_clarity(socket)

    socket =
      with {:ok, socket} <- fetch_lens(socket, lens_id),
           {:ok, socket} <- fetch_vertex(socket, vertex_id, content_id) do
        socket
      else
        {:error, socket, reason} ->
          data_error(socket, reason)
      end

    socket
    |> load_data_async()
    |> update_page_title()
  end

  @spec fetch_clarity(Socket.t()) :: Socket.t()
  defp fetch_clarity(socket) do
    clarity = Clarity.get(socket.assigns.clarity_pid, :partial)
    update_count = Graph.get_update_count(clarity.graph)

    assign(socket, clarity: clarity, update_count: update_count)
  end

  @spec fetch_lens(Socket.t(), String.t()) ::
          {:ok, Socket.t()} | {:error, Socket.t(), :lens_not_found}
  defp fetch_lens(socket, lens_id) do
    case Lensmaker.get_lens_by_id(lens_id) do
      {:ok, lens} ->
        available_vertex_types =
          socket.assigns.clarity.graph
          |> Graph.available_vertex_types()
          |> Enum.reject(&(&1 == Root))

        shown_vertex_types = lens.show_vertex_types.(available_vertex_types)

        {:ok,
         assign(socket,
           lens: lens,
           shown_vertex_types: shown_vertex_types,
           available_vertex_types: available_vertex_types
         )}

      {:error, :lens_not_found} ->
        {:error,
         assign(socket,
           lens: nil,
           vertex: nil,
           content: nil,
           contents: [],
           shown_vertex_types: [],
           available_vertex_types: []
         ), :lens_not_found}
    end
  end

  @spec fetch_vertex(Socket.t(), String.t(), String.t()) ::
          {:ok, Socket.t()} | {:error, Socket.t(), :vertex_not_found}
  defp fetch_vertex(socket, vertex_id, content_id) do
    case Graph.get_vertex(socket.assigns.clarity.graph, vertex_id) do
      nil ->
        {:error,
         assign(socket,
           vertex: nil,
           content: nil,
           contents: [],
           vertex_status_classes: %{}
         ), :vertex_not_found}

      vertex ->
        contents = Content.get_contents_for_vertex(vertex, socket.assigns.lens)
        content = Enum.find(contents, &(&1.id == content_id))

        breadcrumbs = Graph.breadcrumbs(socket.assigns.clarity.graph, vertex) || [vertex]

        vertex_status_classes =
          Status.Index.vertex_classes(socket.assigns.clarity.graph, vertex, socket.assigns.lens)

        {:ok,
         socket
         |> reveal_tree_path(breadcrumbs)
         |> assign(
           vertex: vertex,
           contents: contents,
           content: content,
           breadcrumbs: breadcrumbs,
           vertex_status_classes: vertex_status_classes
         )}
    end
  end

  # The tree opens the path to the current vertex and keeps it open after
  # navigating elsewhere, like any node the user expanded. When the path
  # changes, the user's collapses of nodes and groups along it are dropped, so
  # navigating always reveals the new vertex; collapses elsewhere, and
  # re-rendering the same path (a tab switch, a graph refresh), keep them.
  @spec reveal_tree_path(Socket.t(), [Vertex.t()]) :: Socket.t()
  defp reveal_tree_path(socket, breadcrumbs) do
    path = Enum.map(breadcrumbs, &Vertex.id/1)
    previous_path = socket.assigns |> Map.get(:breadcrumbs, []) |> Enum.map(&Vertex.id/1)

    if path == previous_path do
      socket
    else
      path_ids = TreeComponent.path_ids(socket.assigns.clarity.graph, breadcrumbs)

      socket
      |> update(:tree_opened, &MapSet.union(&1, path_ids))
      |> update(:tree_collapsed, &MapSet.difference(&1, path_ids))
    end
  end

  @spec data_error(Socket.t(), term()) :: Socket.t()
  defp data_error(socket, reason) do
    if socket.assigns.data.ok? do
      Graph.delete(socket.assigns.data.result.graph)
      Graph.delete(socket.assigns.data.result.zoom_graph)
    end

    assign(socket, data: AsyncResult.failed(AsyncResult.loading(), reason))
  end

  @spec load_data_async(Socket.t()) :: Socket.t()
  defp load_data_async(socket)

  defp load_data_async(%Socket{assigns: %{vertex: nil}} = socket), do: socket

  defp load_data_async(socket) do
    %{
      clarity: clarity,
      lens: lens,
      vertex: vertex,
      zoom_level: zoom_level,
      shown_vertex_types: shown_vertex_types
    } = socket.assigns

    liveview_pid = self()

    assign_async(
      socket,
      :data,
      fn ->
        # Framework internals are hidden unless the lens shows them.
        hidden_ids = if lens.show_internals?, do: [], else: Internals.ids(clarity.graph)

        graph = compute_subgraph(clarity.graph, lens, vertex, shown_vertex_types, hidden_ids)

        {outgoing_steps, incoming_steps} = zoom_level

        zoom_graph =
          Graph.filter(
            graph,
            Graph.Filter.within_steps(vertex, outgoing_steps, incoming_steps)
          )

        {:ok, graph} = Graph.handover(graph, liveview_pid)
        {:ok, zoom_graph} = Graph.handover(zoom_graph, liveview_pid)

        {:ok, %{data: %{graph: graph, zoom_graph: zoom_graph}}}
      end
    )
  end

  # Vertices in `hidden_ids` are removed before the lens filters the graph, so
  # the lens treats them as absent; those on the path to `vertex` are kept.
  @spec compute_subgraph(Graph.t(), Lens.t(), Vertex.t(), [module()], [String.t()]) ::
          Graph.t()
  defp compute_subgraph(graph, lens, vertex, shown_vertex_types, hidden_ids) do
    lens_filter =
      if shown_vertex_types == [] do
        lens.filter
      else
        Graph.Filter.all([
          lens.filter,
          Graph.Filter.vertex_type(shown_vertex_types)
        ])
      end

    breadcrumb_ids =
      graph
      |> Graph.breadcrumbs(vertex)
      |> Kernel.||([vertex])
      |> Enum.map(&Vertex.id/1)

    context_filter =
      Graph.Filter.any([
        lens_filter,
        Graph.Filter.vertex_type([Root]),
        {:in, :vertex_id, breadcrumb_ids}
      ])

    case hidden_ids -- breadcrumb_ids do
      [] ->
        Graph.filter(graph, context_filter)

      hidden_ids ->
        visible = Graph.filter(graph, {:not, {:in, :vertex_id, hidden_ids}})

        try do
          Graph.filter(visible, context_filter)
        after
          Graph.delete(visible)
        end
    end
  end

  @impl Phoenix.LiveView
  def handle_event("viz:click", %{"id" => id}, socket) do
    graph_content_id = Content.content_id(Content.Graph)

    {:noreply,
     push_patch(socket,
       to: Path.join([socket.assigns.prefix, socket.assigns.lens.id, id, graph_content_id])
     )}
  end

  def handle_event("toggle_navigation", _params, socket) do
    {:noreply, assign(socket, show_navigation: not socket.assigns.show_navigation)}
  end

  def handle_event("toggle_raw_drawer", _params, socket) do
    {:noreply, assign(socket, show_raw_drawer: not socket.assigns.show_raw_drawer)}
  end

  def handle_event("close_raw_drawer", _params, socket) do
    {:noreply, assign(socket, show_raw_drawer: false)}
  end

  @impl Phoenix.LiveView
  def handle_info({:clarity, event}, socket) when event in [:work_started, :work_completed] do
    {:noreply, handle_routing(socket, socket.assigns.params, &push_patch/2)}
  end

  def handle_info({:flash, kind, message}, socket) do
    {:noreply, put_flash(socket, kind, message)}
  end

  def handle_info(:refresh, socket) do
    clarity = Clarity.get(socket.assigns.clarity_pid, :partial)
    new_update_count = Graph.get_update_count(clarity.graph)

    socket =
      cond do
        new_update_count == socket.assigns.update_count and
            clarity.status == socket.assigns.clarity.status ->
          socket

        new_update_count == socket.assigns.update_count ->
          assign(socket, clarity: clarity)

        socket.assigns.data.ok? ->
          socket
          |> assign(clarity: clarity, update_count: new_update_count)
          |> load_data_async()

        true ->
          socket
          |> assign(clarity: clarity, update_count: new_update_count)
          |> handle_routing(socket.assigns.params, &push_patch/2)
      end

    {:noreply, socket}
  end

  def handle_info({:"ETS-TRANSFER", _ref, _pid, :graph_handover}, socket) do
    {:noreply, socket}
  end

  def handle_info({:update_zoom_level, zoom_level}, socket) do
    {:noreply, socket |> assign(zoom_level: zoom_level) |> load_data_async()}
  end

  def handle_info({:update_shown_vertex_types, shown_vertex_types}, socket) do
    {:noreply, socket |> assign(shown_vertex_types: shown_vertex_types) |> load_data_async()}
  end

  def handle_info({:update_tree_state, opened, collapsed}, socket) do
    {:noreply, assign(socket, tree_opened: opened, tree_collapsed: collapsed)}
  end

  @spec update_page_title(Socket.t()) :: Socket.t()
  defp update_page_title(socket)

  defp update_page_title(%Socket{assigns: %{lens: nil}} = socket),
    do: assign(socket, page_title: "Lens Not Found")

  defp update_page_title(%Socket{assigns: %{vertex: nil}} = socket),
    do: assign(socket, page_title: "Vertex Not Found")

  defp update_page_title(socket) do
    page_title =
      socket.assigns.breadcrumbs
      |> Enum.drop(1)
      |> Enum.reverse()
      |> Enum.map_join(" · ", &Vertex.name/1)

    assign(socket, page_title: page_title)
  end

  @spec get_first_content_id([Content.t()]) :: String.t()
  defp get_first_content_id(contents) do
    [%{id: id} | _] = contents
    id
  end
end
