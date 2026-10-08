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
        content: nil,
        page_title: "Loading...",
        shown_vertex_types: [],
        available_vertex_types: [],
        initial_vertex: initial_vertex,
        lenses: Lensmaker.get_all_lenses()
      )
      |> fetch_clarity()
      # LiveView forbids live patches during mount, which a live navigation to a
      # bare lens URL (e.g. from the reports to a lens) would otherwise trigger.
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

      {%{"lens" => lens_id, "vertex" => vertex_id} = params, :vertex} ->
        handle_vertex_route(lens_id, vertex_id, params["status"], socket, navigate_fn)

      {%{"lens" => lens_id, "vertex" => vertex_id, "content" => content_id}, :page} ->
        handle_page_route(lens_id, vertex_id, content_id, socket, navigate_fn)
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

  @spec handle_vertex_route(String.t(), String.t(), String.t() | nil, Socket.t(), navigation_fn) ::
          Socket.t()
        when navigation_fn: (Socket.t(), keyword() -> Socket.t())
  defp handle_vertex_route(lens_id, vertex_id, status, socket, navigate_fn) do
    clarity = Clarity.get(socket.assigns.clarity_pid, :partial)

    with {:ok, lens} <- Lensmaker.get_lens_by_id(lens_id),
         vertex when not is_nil(vertex) <- Graph.get_vertex(clarity.graph, vertex_id) do
      case Content.get_contents_for_vertex(vertex, lens) do
        [] -> handle_tabless_vertex(lens_id, vertex, status, socket, navigate_fn)
        contents -> navigate_fn.(socket, to: page_path(socket, lens, vertex_id, contents, status))
      end
    else
      _ ->
        navigate_fn.(socket, to: Path.join([socket.assigns.prefix, lens_id, "root"]))
    end
  end

  # This lens has no tab for the vertex, so open it in the first lens that
  # has one; when none has, show it here, saying so.
  @spec handle_tabless_vertex(String.t(), Vertex.t(), String.t() | nil, Socket.t(), navigation_fn) ::
          Socket.t()
        when navigation_fn: (Socket.t(), keyword() -> Socket.t())
  defp handle_tabless_vertex(lens_id, vertex, status, socket, navigate_fn) do
    vertex_id = Vertex.id(vertex)

    case lens_with_tab(socket, vertex, nil) do
      {lens, contents} ->
        navigate_fn.(socket,
          to: page_path(socket, lens, vertex_id, contents, status),
          replace: true
        )

      nil ->
        handle_page_route(lens_id, vertex_id, nil, socket, navigate_fn)
    end
  end

  @spec page_path(Socket.t(), Lens.t(), String.t(), [Content.t()], String.t() | nil) ::
          String.t()
  defp page_path(socket, lens, vertex_id, contents, status) do
    content_id = chosen_content_id(contents, socket.assigns.content, status)
    Path.join([socket.assigns.prefix, lens.id, vertex_id, content_id])
  end

  @spec handle_page_route(
          String.t(),
          String.t(),
          String.t() | nil,
          Socket.t(),
          (Socket.t(), keyword() -> Socket.t())
        ) :: Socket.t()
  defp handle_page_route(lens_id, vertex_id, content_id, socket, navigate_fn) do
    socket = fetch_clarity(socket)

    socket =
      with {:ok, socket} <- fetch_lens(socket, lens_id),
           {:ok, socket} <- fetch_vertex(socket, vertex_id, content_id) do
        socket
      else
        {:error, socket, reason} ->
          data_error(socket, reason)
      end

    case missing_tab(socket, content_id) do
      nil -> socket |> load_data_async() |> update_page_title()
      path -> navigate_fn.(socket, to: path, replace: true)
    end
  end

  # Where to go when this lens hasn't the tab asked for: the first lens, in
  # the activity bar's order, that has it. A tab no lens has stays put, so
  # the page says it wasn't found.
  @spec missing_tab(Socket.t(), String.t() | nil) :: String.t() | nil
  defp missing_tab(%{assigns: %{vertex: vertex, content: nil}} = socket, content_id)
       when vertex != nil and content_id != nil do
    case lens_with_tab(socket, vertex, content_id) do
      {lens, _contents} ->
        Path.join([socket.assigns.prefix, lens.id, Vertex.id(vertex), content_id])

      nil ->
        nil
    end
  end

  defp missing_tab(_socket, _content_id), do: nil

  # The first lens, in the activity bar's order, with a tab for the vertex
  # (the one with `content_id`, if given), and its tabs.
  @spec lens_with_tab(Socket.t(), Vertex.t(), String.t() | nil) :: {Lens.t(), [Content.t()]} | nil
  defp lens_with_tab(socket, vertex, content_id) do
    Enum.find_value(socket.assigns.lenses, fn lens ->
      contents = Content.get_contents_for_vertex(vertex, lens)

      if contents != [] and (content_id == nil or Enum.any?(contents, &(&1.id == content_id))),
        do: {lens, contents}
    end)
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

  @spec fetch_vertex(Socket.t(), String.t(), String.t() | nil) ::
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

  # Switching lens keeps the selected vertex, so its other lenses can be seen,
  # or moves up to its nearest ancestor that the new lens's tree shows. The tab
  # stays too, if the new lens has it.
  @impl Phoenix.LiveView
  def handle_event("switch_lens", %{"lens" => lens_id}, socket) do
    case {Lensmaker.get_lens_by_id(lens_id), socket.assigns.vertex} do
      {{:error, :lens_not_found}, _vertex} ->
        {:noreply, socket}

      {{:ok, lens}, nil} ->
        {:noreply, push_patch(socket, to: Path.join([socket.assigns.prefix, lens.id]))}

      {{:ok, lens}, vertex} ->
        {:noreply, push_patch(socket, to: lens_switch_path(socket, lens, vertex))}
    end
  end

  def handle_event("viz:click", %{"id" => id}, socket) do
    graph_content_id = Content.content_id(Content.Graph)

    {:noreply,
     push_patch(socket,
       to: Path.join([socket.assigns.prefix, socket.assigns.lens.id, id, graph_content_id])
     )}
  end

  # A diagram among an overview's sections opens the vertex's own page.
  def handle_event("viz:open", %{"id" => id}, socket) do
    {:noreply,
     push_patch(socket, to: Path.join([socket.assigns.prefix, socket.assigns.lens.id, id]))}
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
    do: assign(socket, page_title: "Lens not found")

  defp update_page_title(%Socket{assigns: %{vertex: nil}} = socket),
    do: assign(socket, page_title: "Vertex not found")

  defp update_page_title(socket) do
    page_title =
      socket.assigns.breadcrumbs
      |> Enum.drop(1)
      |> Enum.reverse()
      |> Enum.map_join(" · ", &Vertex.name/1)

    assign(socket, page_title: page_title)
  end

  # The breadcrumbs leading to the current vertex, leaving out the root, which
  # every path starts from.
  @spec breadcrumb_trail([Vertex.t()]) :: [Vertex.t()]
  defp breadcrumb_trail(breadcrumbs),
    do: breadcrumbs |> Enum.drop(-1) |> Enum.reject(&match?(%Root{}, &1))

  # The trail's vertices with their names, each leaving out what the crumbs
  # before it say when names are short.
  @spec named_trail([Vertex.t()], Vertex.Name.style()) :: [{Vertex.t(), String.t()}]
  defp named_trail(breadcrumbs, name_style) do
    trail = breadcrumb_trail(breadcrumbs)
    Enum.zip(trail, Vertex.Name.display_path(trail, name_style))
  end

  # The names of the trail and then the vertex itself, as the page's title.
  @spec named_path([Vertex.t()], Vertex.t(), Vertex.Name.style()) :: [String.t()]
  defp named_path(breadcrumbs, vertex, name_style),
    do: Vertex.Name.display_path(breadcrumb_trail(breadcrumbs) ++ [vertex], name_style)

  # The tab that explains `status`, a status class from a status badge's link,
  # if the vertex has one. Otherwise the tab open before, if the vertex has it
  # too, or else its first: moving to another vertex, or lens, keeps the tab
  # where it can.
  @spec chosen_content_id([Content.t(), ...], Content.t() | nil, String.t() | nil) :: String.t()
  defp chosen_content_id([%{id: first_id} | _] = contents, content, status) do
    cond do
      explaining = status && Enum.find(contents, &explains?(&1, status)) -> explaining.id
      content && Enum.any?(contents, &(&1.id == content.id)) -> content.id
      true -> first_id
    end
  end

  @spec explains?(Content.t(), String.t()) :: boolean()
  defp explains?(content, status),
    do: Enum.any?(content.status_classes, &(Atom.to_string(&1) == status))

  # The vertex route then keeps the open tab if the lens has it for the target.
  # When the lens has no tab for it, the lens opens at its start page instead,
  # as the vertex route would move a vertex without tabs to another lens, back
  # where the switch began.
  @spec lens_switch_path(Socket.t(), Lens.t(), Vertex.t()) :: String.t()
  defp lens_switch_path(socket, lens, vertex) do
    %{prefix: prefix, clarity: clarity} = socket.assigns
    shown = nearest_shown(clarity.graph, lens, vertex)

    if Content.get_contents_for_vertex(shown, lens) == [],
      do: Path.join([prefix, lens.id]),
      else: Path.join([prefix, lens.id, Vertex.id(shown)])
  end

  # The vertex itself if the lens's tree shows it, or else its nearest ancestor
  # that the tree does; the root always shows.
  @spec nearest_shown(Graph.t(), Lens.t(), Vertex.t()) :: Vertex.t()
  defp nearest_shown(graph, lens, vertex) do
    path = Graph.breadcrumbs(graph, vertex) || [vertex]
    shown = shown_ids(graph, lens, Enum.map(path, &Vertex.id/1))

    path
    |> Enum.reverse()
    |> Enum.find(hd(path), &(match?(%Root{}, &1) or Vertex.id(&1) in shown))
  end

  # Which of `ids` the lens's tree shows, by the same rules as compute_subgraph/5:
  # its filter, its vertex types, and whether it shows framework internals.
  @spec shown_ids(Graph.t(), Lens.t(), [String.t()]) :: MapSet.t(String.t())
  defp shown_ids(graph, lens, ids) do
    available_types = graph |> Graph.available_vertex_types() |> Enum.reject(&(&1 == Root))
    hidden_ids = if lens.show_internals?, do: [], else: Internals.ids(graph)

    type_filter =
      case lens.show_vertex_types.(available_types) do
        [] -> []
        types -> [Graph.Filter.vertex_type(types)]
      end

    query = Graph.Filter.all([lens.filter, {:in, :vertex_id, ids -- hidden_ids} | type_filter])

    graph |> Graph.vertices(query.(graph)) |> MapSet.new(&Vertex.id/1)
  end
end
