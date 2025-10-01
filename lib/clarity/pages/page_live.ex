defmodule Clarity.PageLive do
  @moduledoc false

  use Clarity.Web, :live_view

  alias Clarity.Graph
  alias Clarity.Perspective
  alias Clarity.Vertex
  alias Phoenix.LiveView.Rendered
  alias Phoenix.LiveView.Socket

  @impl Phoenix.LiveView
  def mount(params, _session, socket) do
    if connected?(socket) do
      Clarity.subscribe(socket.assigns.clarity_pid)
      :timer.send_interval(1000, self(), :refresh_interval)
    end

    clarity = Clarity.get(socket.assigns.clarity_pid, :partial)
    {:ok, perspective_pid} = Perspective.start_link(clarity.graph)

    socket =
      socket
      |> assign(clarity: clarity, perspective_pid: perspective_pid, show_navigation: false)
      |> handle_routing(params, &push_navigate/2)

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _url, socket) do
    {:noreply, handle_routing(socket, params, &push_patch/2)}
  end

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
    lens = Perspective.get_current_lens(socket.assigns.perspective_pid)
    socket = assign(socket, lens: lens)
    navigate_fn.(socket, to: Path.join([socket.assigns.prefix, lens.id]))
  end

  @spec handle_lens_route(String.t(), Socket.t(), (Socket.t(), keyword() -> Socket.t())) ::
          Socket.t()
  defp handle_lens_route(lens_id, socket, navigate_fn) do
    Perspective.install_lens(socket.assigns.perspective_pid, lens_id)

    vertex = Perspective.get_current_vertex(socket.assigns.perspective_pid)
    lens = Perspective.get_current_lens(socket.assigns.perspective_pid)

    navigate_fn.(socket,
      to: Path.join([socket.assigns.prefix, lens.id, Vertex.unique_id(vertex)])
    )
  end

  @spec handle_vertex_route(String.t(), String.t(), Socket.t(), navigation_fn) :: Socket.t()
        when navigation_fn: (Socket.t(), keyword() -> Socket.t())
  defp handle_vertex_route(lens_id, vertex_id, socket, navigate_fn) do
    Perspective.install_lens(socket.assigns.perspective_pid, lens_id)
    Perspective.set_current_vertex(socket.assigns.perspective_pid, vertex_id)

    lens = Perspective.get_current_lens(socket.assigns.perspective_pid)
    first_content_id = get_first_content_id(socket.assigns.perspective_pid)

    navigate_fn.(socket,
      to: Path.join([socket.assigns.prefix, lens.id, vertex_id, first_content_id])
    )
  end

  @spec handle_page_route(String.t(), String.t(), String.t(), Socket.t()) :: Socket.t()
  defp handle_page_route(lens_id, vertex_id, content_id, socket) do
    clarity = Clarity.get(socket.assigns.clarity_pid, :partial)

    socket = assign(socket, clarity: clarity, show_navigation: false)

    case Perspective.install_lens(socket.assigns.perspective_pid, lens_id) do
      {:error, :lens_not_found} ->
        assign(socket,
          lens: nil,
          current_vertex: nil,
          current_content: nil,
          contents: [],
          breadcrumbs: [],
          tree: nil,
          page_title: "Lens Not Found"
        )

      {:ok, lens} ->
        tree = Perspective.get_tree(socket.assigns.perspective_pid)

        socket = assign(socket, lens: lens, tree: tree)

        case Perspective.set_current_vertex(socket.assigns.perspective_pid, vertex_id) do
          {:error, :vertex_not_found} ->
            assign(socket,
              current_vertex: nil,
              current_content: nil,
              contents: [],
              breadcrumbs: [],
              page_title: "Vertex Not Found"
            )

          {:ok, vertex} ->
            breadcrumbs = Perspective.get_breadcrumbs(socket.assigns.perspective_pid)
            contents = Perspective.get_contents(socket.assigns.perspective_pid)

            socket =
              socket
              |> assign(current_vertex: vertex, contents: contents, breadcrumbs: breadcrumbs)
              |> update_page_title()

            # credo:disable-for-next-line Credo.Check.Refactor.Nesting
            case Perspective.get_content(socket.assigns.perspective_pid, content_id) do
              {:error, :content_not_found} ->
                assign(socket, current_content: nil, page_title: "Content Not Found")

              {:ok, content} ->
                assign(socket, current_content: content)
            end
        end
    end
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.flash_group flash={@flash} />
    <%= case @lens do %>
      <% nil -> %>
        <.lens_not_found_error prefix={@prefix} />
      <% lens -> %>
        <article class="layout-container bg-base-light-50 dark:bg-base-dark-900 text-base-light-900 dark:text-base-dark-100">
          <.header
            prefix={@prefix}
            lens={@lens}
            theme={@theme}
            refreshing={@clarity.status == :working}
            work_status={@clarity.status}
            queue_info={@clarity.queue_info}
            class="header z-10"
          />

          <.navigation
            tree={@tree}
            prefix={@prefix}
            lens={lens}
            current={@current_vertex}
            breadcrumbs={@breadcrumbs}
            class={"navigation bg-base-light-100 dark:bg-base-dark-800 border-r border-base-light-300 dark:border-base-dark-700 p-4 md:block #{if @show_navigation, do: "block", else: "hidden"}"}
          />

          <%= if @current_vertex do %>
            <div class="title bg-base-light-50 dark:bg-base-dark-900 border-b border-base-light-300 dark:border-base-dark-700 px-4 py-3 flex items-center">
              <nav class="breadcrumbs mr-3">
                <ol class="flex flex-wrap text-xs text-base-light-600 dark:text-base-dark-400 space-x-1">
                  <%= for {breadcrumb, idx} <- Enum.with_index(Enum.drop(@breadcrumbs, -1)), idx > 0 do %>
                    <li class="flex items-center">
                      <span :if={idx > 1} class="mx-1 text-base-light-500 dark:text-base-dark-600">
                        →
                      </span>
                      <.link
                        patch={Path.join([@prefix, @lens.id, Vertex.unique_id(breadcrumb)])}
                        class="hover:text-primary-light dark:hover:text-primary-dark transition-colors"
                      >
                        <.vertex_name vertex={breadcrumb} />
                      </.link>
                    </li>
                  <% end %>
                  <%= if length(@breadcrumbs) > 1 do %>
                    <li class="flex items-center">
                      <span class="mx-1 text-base-light-500 dark:text-base-dark-600">→</span>
                    </li>
                  <% end %>
                </ol>
              </nav>
              <h1 class="text-2xl font-bold text-base-light-900 dark:text-base-dark-100">
                {Vertex.render_name(@current_vertex)}
              </h1>
            </div>
            <.tabs
              contents={@contents}
              current_content={@current_content}
              prefix={@prefix}
              current_vertex={@current_vertex}
              lens={lens}
            />
            <.render_content content={@current_content} socket={@socket} theme={@theme} />
          <% else %>
            <.vertex_not_found_error prefix={@prefix} lens={lens} />
          <% end %>
        </article>
        <.render_tooltips graph={@clarity.graph} />
    <% end %>
    """
  end

  @impl Phoenix.LiveView
  def handle_event("viz:click", %{"id" => id}, socket) do
    {:noreply,
     push_patch(socket, to: Path.join([socket.assigns.prefix, socket.assigns.lens.id, id]))}
  end

  def handle_event("toggle_navigation", _params, socket) do
    {:noreply, assign(socket, show_navigation: not socket.assigns.show_navigation)}
  end

  def handle_event("refresh", _params, socket) do
    Clarity.introspect(socket.assigns.clarity_pid)
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:clarity, event}, socket) when event in [:work_started, :work_completed] do
    {:noreply, handle_routing(socket, socket.assigns.params, &push_patch/2)}
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
      {:noreply, handle_routing(socket, socket.assigns.params, &push_patch/2)}
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
            patch={
              Path.join([@prefix, @lens.id, Clarity.Vertex.unique_id(@current_vertex), content.id])
            }
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

  @spec lens_not_found_error(assigns :: Socket.assigns()) :: Rendered.t()
  defp lens_not_found_error(assigns) do
    ~H"""
    <div class="bg-base-light-50 dark:bg-base-dark-900 text-base-light-900 dark:text-base-dark-100 min-h-screen w-full flex items-center justify-center p-8">
      <div class="max-w-lg w-full text-center">
        <h1 class="text-4xl font-bold text-base-light-900 dark:text-base-dark-100 mb-6">
          Lens Not Found
        </h1>
        <p class="text-lg text-base-light-600 dark:text-base-dark-400 mb-8">
          The requested lens could not be found. It may not be available or the URL is incorrect.
        </p>
        <.link
          patch={@prefix}
          class="inline-flex items-center px-6 py-3 border border-transparent text-base font-medium rounded-md shadow-sm text-white bg-primary-light hover:bg-primary-light/90 dark:bg-primary-dark dark:hover:bg-primary-dark/90 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-light dark:focus:ring-primary-dark"
        >
          ← Go to Default Page
        </.link>
      </div>
    </div>
    """
  end

  @spec vertex_not_found_error(assigns :: Socket.assigns()) :: Rendered.t()
  defp vertex_not_found_error(assigns) do
    ~H"""
    <div class="content p-8 text-center">
      <div class="max-w-md mx-auto">
        <h1 class="text-3xl font-bold text-base-light-900 dark:text-base-dark-100 mb-4">
          Vertex Not Found
        </h1>
        <p class="text-base-light-600 dark:text-base-dark-400 mb-6">
          The requested vertex could not be found. It may have been removed or the URL is incorrect.
        </p>
        <.link
          patch={Path.join([@prefix, @lens.id, "root"])}
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
          The requested content could not be found for this vertex. Try selecting a different tab above.
        </p>
      </div>
    </div>
    """
  end

  @spec update_page_title(Socket.t()) :: Socket.t()
  defp update_page_title(socket) do
    page_title =
      socket.assigns.breadcrumbs
      |> Enum.drop(1)
      |> Enum.reverse()
      |> Enum.map_join(" · ", &Vertex.render_name/1)

    assign(socket, page_title: page_title)
  end

  @spec get_first_content_id(pid()) :: String.t()
  defp get_first_content_id(perspective_pid) do
    [%{id: id} | _] = Perspective.get_contents(perspective_pid)

    id
  end
end
