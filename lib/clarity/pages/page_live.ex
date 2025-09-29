defmodule Clarity.PageLive do
  @moduledoc false

  use Clarity.Web, :live_view

  alias Clarity.Graph
  alias Clarity.Graph.Filter
  alias Clarity.Vertex
  alias Phoenix.LiveView.Rendered
  alias Phoenix.LiveView.Socket

  @impl Phoenix.LiveView
  def mount(%{"vertex" => vertex_id, "content" => content} = _params, _session, socket) do
    socket = setup_socket(socket)

    vertex = Graph.get_vertex(socket.assigns.clarity.graph, vertex_id)

    {:ok, socket |> assign(vertex_id: vertex_id) |> update_dynamics(vertex, content)}
  end

  def mount(params, %{"prefix" => prefix} = _session, socket) when params == %{} do
    socket = setup_socket(socket)

    {:ok, push_navigate(socket, to: Path.join([prefix, "root", "graph"]))}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"vertex" => vertex_id, "content" => content}, _url, socket) do
    vertex = Graph.get_vertex(socket.assigns.clarity.graph, vertex_id)

    {:noreply,
     socket
     |> assign(vertex_id: vertex_id)
     |> assign(show_navigation: false)
     |> update_dynamics(vertex, content)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.flash_group flash={@flash} />
    <article class="layout-container bg-base-light-50 dark:bg-base-dark-900 text-base-light-900 dark:text-base-dark-100">
      <.header
        breadcrumbs={@breadcrumbs}
        prefix={@prefix}
        theme={@theme}
        refreshing={@clarity.status == :working}
        work_status={@clarity.status}
        queue_info={@clarity.queue_info}
        class="header z-10"
      />

      <.navigation
        tree={@tree}
        prefix={@prefix}
        current={@current_vertex}
        breadcrumbs={@breadcrumbs}
        class={"navigation bg-base-light-100 dark:bg-base-dark-800 border-r border-base-light-300 dark:border-base-dark-700 p-4 md:block #{if @show_navigation, do: "block", else: "hidden"}"}
      />

      <%= if @current_vertex do %>
        <.tabs
          contents={@contents}
          current_content={@current_content}
          prefix={@prefix}
          current_vertex={@current_vertex}
        />
        <.render_content content={@current_content} socket={@socket} theme={@theme} />
      <% else %>
        <.node_not_found_error prefix={@prefix} />
      <% end %>
    </article>
    <.render_tooltips graph={@clarity.graph} />
    """
  end

  @impl Phoenix.LiveView
  def handle_event("viz:click", %{"id" => id}, socket) do
    {:noreply, push_patch(socket, to: Path.join([socket.assigns.prefix, id, "graph"]))}
  end

  def handle_event("toggle_navigation", _params, socket) do
    {:noreply, assign(socket, show_navigation: not socket.assigns.show_navigation)}
  end

  def handle_event("refresh", _params, socket) do
    Clarity.introspect(socket.assigns.clarity_pid)
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:clarity, :work_started}, socket) do
    {:noreply, load_clarity(socket)}
  end

  def handle_info({:clarity, :work_completed}, socket) do
    vertex = Graph.get_vertex(socket.assigns.clarity.graph, socket.assigns.vertex_id)

    socket =
      socket
      |> load_clarity()
      |> update_dynamics(
        vertex,
        socket.assigns.current_content && socket.assigns.current_content.id
      )

    {:noreply, socket}
  end

  def handle_info({:clarity, {:work_progress, _progress_info}}, socket) do
    # Ignore progress events - let the interval handle regular updates
    {:noreply, socket}
  end

  def handle_info({:flash, kind, message}, socket) do
    {:noreply, put_flash(socket, kind, message)}
  end

  def handle_info(:refresh_interval, socket) do
    # Only refresh if work is in progress to avoid unnecessary calls
    if socket.assigns.clarity.status == :working do
      vertex = Graph.get_vertex(socket.assigns.clarity.graph, socket.assigns.vertex_id)

      socket =
        socket
        |> load_clarity()
        |> update_dynamics(
          vertex,
          socket.assigns.current_content && socket.assigns.current_content.id
        )

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @spec tabs(assigns :: Socket.assigns()) :: Rendered.t()
  defp tabs(assigns) do
    ~H"""
    <nav class="tabs border-b border-base-light-300 dark:border-base-dark-700 bg-base-light-100 dark:bg-base-dark-900 px-4 flex justify-between items-center">
      <ul class="flex space-x-2">
        <li :for={content <- @contents}>
          <.link
            patch={Path.join([@prefix, Clarity.Vertex.unique_id(@current_vertex), content.id])}
            class={
            "inline-block px-4 py-2 rounded-t-md font-medium transition-colors " <>
            if @current_content && content.id == @current_content.id,
              do: "bg-base-light-200 dark:bg-base-dark-800 text-primary-light dark:text-primary-dark border-b-2 border-primary-light dark:border-primary-dark",
              else: "text-base-light-600 dark:text-base-dark-400 hover:text-primary-light dark:hover:text-primary-dark hover:bg-base-light-200 dark:hover:bg-base-dark-800"
            }
          >
            <.vertex_name vertex={content} />
          </.link>
        </li>
      </ul>
      
    <!-- Editor button section -->
      <div class="flex items-center">
        <%= if Vertex.source_location(@current_vertex) != nil do %>
          <.live_component
            module={Clarity.EditorButtonComponent}
            id="editor-button"
            source_location={Vertex.source_location(@current_vertex)}
          />
        <% end %>
      </div>
    </nav>
    """
  end

  @spec render_content(assigns :: Socket.assigns()) :: Rendered.t()
  defp render_content(assigns) do
    ~H"""
    <%= if @content do %>
      <%= case @content.content do %>
        <% {:mermaid, content} when is_function(content, 0) -> %>
          <.mermaid graph={content.()} class="content p-4" id="content-view-mermaid" />
        <% {:mermaid, content} -> %>
          <.mermaid graph={content} class="content p-4" id="content-view-mermaid" />
        <% {:viz, content} when is_function(content, 1) -> %>
          <.viz graph={content.(%{theme: @theme})} class="content p-4" id="content-view-viz" />
        <% {:viz, content} when is_function(content, 0) -> %>
          <.viz graph={content.()} class="content p-4" id="content-view-viz" />
        <% {:viz, content} -> %>
          <.viz graph={content} class="content p-4" id="content-view-viz" />
        <% {:markdown, content} when is_function(content, 0) -> %>
          <.markdown content={content.()} class="content p-4" />
        <% {:markdown, content} -> %>
          <.markdown content={content} class="content p-4" />
        <% {:live_view, {module, session}} -> %>
          {live_render(@socket, module,
            id: "content-view",
            session: session,
            container: {:div, class: "content"}
          )}
      <% end %>
    <% else %>
      <.content_not_found_error />
    <% end %>
    """
  end

  @spec render_tooltips(assigns :: Socket.assigns()) :: Rendered.t()
  defp render_tooltips(assigns) do
    ~H"""
    <%= for vertex <- Graph.vertices(@graph),
          %mod{} = vertex,
          mod != Vertex.Content,
          overview = vertex |> Vertex.markdown_overview() |> IO.iodata_to_binary() |> String.trim(),
          overview != "" do %>
      <div id={"tooltip-#{Vertex.unique_id(vertex)}"} phx-hook="Tooltip" class="tooltip hidden py-5">
        <div class="border border-base-light-400 dark:border-base-dark-600 shadow-lg bg-white dark:bg-base-dark-800 text-gray-900 dark:text-base-dark-100 px-4 py-2 rounded">
          <.markdown content={overview} />
        </div>
      </div>
    <% end %>
    """
  end

  @spec node_not_found_error(assigns :: Socket.assigns()) :: Rendered.t()
  defp node_not_found_error(assigns) do
    ~H"""
    <div class="content p-8 text-center">
      <div class="max-w-md mx-auto">
        <h1 class="text-3xl font-bold text-base-light-900 dark:text-base-dark-100 mb-4">
          Node Not Found
        </h1>
        <p class="text-base-light-600 dark:text-base-dark-400 mb-6">
          The requested node could not be found. It may have been removed or the URL is incorrect.
        </p>
        <.link
          patch={Path.join([@prefix, "root", "graph"])}
          class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-primary-light hover:bg-primary-light/90 dark:bg-primary-dark dark:hover:bg-primary-dark/90 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-light dark:focus:ring-primary-dark"
        >
          ← Go to Root
        </.link>
      </div>
    </div>
    """
  end

  @spec content_not_found_error(assigns :: Socket.assigns()) :: Rendered.t()
  defp content_not_found_error(assigns) do
    ~H"""
    <div class="content p-8 text-center">
      <div class="max-w-md mx-auto">
        <h2 class="text-2xl font-bold text-base-light-900 dark:text-base-dark-100 mb-4">
          Content Not Found
        </h2>
        <p class="text-base-light-600 dark:text-base-dark-400 mb-6">
          The requested content could not be found for this node. Try selecting a different tab above.
        </p>
      </div>
    </div>
    """
  end

  @spec setup_socket(socket :: Socket.t()) :: Socket.t()
  defp setup_socket(socket) do
    if connected?(socket) do
      Clarity.subscribe(socket.assigns.clarity_pid)
      :timer.send_interval(1000, self(), :refresh_interval)
    end

    socket
    |> load_clarity()
    |> assign(show_navigation: false)
  end

  @spec update_dynamics(
          socket :: Socket.t(),
          current_vertex :: Vertex.t() | nil,
          current_content :: String.t()
        ) :: Socket.t()
  defp update_dynamics(socket, current_vertex, current_content) do
    socket
    |> assign(current_vertex: current_vertex)
    |> update_tree()
    |> update_breadcrumbs(current_vertex)
    |> then(&update_page_title(&1, current_vertex, &1.assigns.breadcrumbs))
    |> update_subgraph(current_vertex)
    |> update_contents(current_vertex, current_content)
  end

  @spec update_page_title(Socket.t(), Vertex.t() | nil, [Vertex.t()]) :: Socket.t()
  defp update_page_title(socket, current_vertex, breadcrumbs)

  defp update_page_title(socket, nil, _breadcrumbs),
    do: assign(socket, page_title: "Page Not Found")

  defp update_page_title(socket, _current_vertex, breadcrumbs) do
    page_title =
      breadcrumbs
      |> Enum.drop(1)
      |> Enum.reverse()
      |> Enum.map_join(" · ", &Vertex.render_name/1)

    assign(socket, page_title: page_title)
  end

  @spec update_tree(Socket.t()) :: Socket.t()
  defp update_tree(socket) do
    tree = Graph.to_tree(socket.assigns.clarity.graph)
    assign(socket, tree: tree)
  end

  @spec update_breadcrumbs(Socket.t(), Vertex.t() | nil) :: Socket.t()
  defp update_breadcrumbs(socket, current_vertex)
  defp update_breadcrumbs(socket, nil), do: assign(socket, breadcrumbs: [])

  defp update_breadcrumbs(socket, current_vertex) do
    breadcrumbs = Graph.breadcrumbs(socket.assigns.clarity.graph, current_vertex) || []

    assign(socket, breadcrumbs: breadcrumbs)
  end

  @spec update_subgraph(Socket.t(), Vertex.t() | nil) :: Socket.t()
  defp update_subgraph(socket, current_vertex)
  defp update_subgraph(socket, nil), do: assign(socket, subgraph: Graph.new())

  defp update_subgraph(socket, current_vertex) do
    if socket.assigns[:subgraph], do: Graph.delete(socket.assigns.subgraph)

    subgraph =
      Graph.filter(
        socket.assigns.clarity.graph,
        Filter.within_steps(current_vertex, 2, 1)
      )

    assign(socket, subgraph: subgraph)
  end

  @spec update_contents(Socket.t(), Vertex.t() | nil, String.t() | nil) :: Socket.t()
  defp update_contents(socket, current_vertex, current_content_id)
  defp update_contents(socket, nil, _), do: assign(socket, contents: [], current_content: nil)

  defp update_contents(socket, current_vertex, current_content_id) do
    %Clarity{graph: clarity_graph} = socket.assigns.clarity

    contents =
      clarity_graph
      |> Graph.out_edges(current_vertex)
      |> Enum.map(&Graph.edge(clarity_graph, &1))
      |> Enum.filter(fn {_, _, _, label} -> label == :content end)
      |> Enum.map(fn {_, _, to_vertex, _} -> to_vertex end)

    contents = [
      %Vertex.Content{
        id: "graph",
        name: "Graph Navigation",
        content:
          {:viz,
           fn %{theme: theme} ->
             Graph.DOT.to_dot(
               socket.assigns.subgraph,
               theme: theme,
               highlight: current_vertex
             )
           end}
      }
      | contents
    ]

    current_content = Enum.find(contents, fn content -> content.id == current_content_id end)

    assign(socket,
      contents: contents,
      current_content: current_content
    )
  end

  @spec load_clarity(Socket.t()) :: Socket.t()
  defp load_clarity(socket) do
    if socket.assigns[:clarity], do: Graph.delete(socket.assigns.clarity.graph)

    clarity =
      socket.assigns.clarity_pid
      |> Clarity.get(:partial)
      |> Map.update!(
        :graph,
        fn graph -> Graph.filter(graph, &temp_ignore_modules_and_empty_applications/1) end
      )

    assign(socket, clarity: clarity)
  end

  # TODO: Make this configurable via the UI
  @spec temp_ignore_modules_and_empty_applications(Graph.t()) :: (Vertex.t() -> boolean())
  defp temp_ignore_modules_and_empty_applications(graph) do
    fn
      # Hide Applications from the navigation / graph. Without user
      # provided filters, this is too noisy to be useful.
      %Vertex.Application{} = vertex ->
        graph
        |> Graph.out_edges(vertex)
        |> Enum.map(&Graph.edge(graph, &1))
        |> Enum.any?(fn
          {_id, ^vertex, _module, :module} -> false
          _other -> true
        end)

      # Hide Modules from the navigation / graph. Without user
      # provided filters, this is too noisy to be useful.
      %Vertex.Module{} ->
        false

      _vertex ->
        true
    end
  end
end
