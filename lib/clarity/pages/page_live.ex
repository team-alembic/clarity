defmodule Clarity.PageLive do
  @moduledoc false

  use Clarity.Web, :live_view

  import Clarity.Components.MarkdownComponent

  alias Clarity.Perspective
  alias Clarity.Vertex
  alias Phoenix.LiveView.AsyncResult
  alias Phoenix.LiveView.Rendered
  alias Phoenix.LiveView.Socket

  @impl Phoenix.LiveView
  def mount(params, session, socket) do
    if connected?(socket) do
      Clarity.subscribe(socket.assigns.clarity_pid, [:work_started, :work_completed])
      Process.send_after(self(), :refresh_interval, to_timeout(second: 1))

      clarity = Clarity.get(socket.assigns.clarity_pid, :partial)
      initial_vertex = Map.get(session, "initial_vertex", "root")
      {:ok, perspective_pid} = Perspective.start_link(clarity.graph, initial_vertex)

      socket =
        socket
        |> assign(
          clarity: clarity,
          perspective_pid: perspective_pid,
          show_navigation: false,
          zoom_subgraph: AsyncResult.loading(),
          loaded?: true
        )
        |> handle_routing(params, &push_navigate/2)

      {:ok, socket}
    else
      {:ok, assign(socket, loaded?: false)}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(params, _url, socket) do
    if socket.assigns.loaded? do
      {:noreply, handle_routing(socket, params, &push_patch/2)}
    else
      {:noreply, socket}
    end
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
      to: Path.join([socket.assigns.prefix, lens.id, Vertex.id(vertex)])
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

    perspective_id = socket.assigns.perspective_pid

    case Perspective.install_lens(perspective_id, lens_id) do
      {:error, :lens_not_found} ->
        assign(socket,
          lens: nil,
          vertex: nil,
          content: nil,
          contents: [],
          breadcrumbs: [],
          subgraph: nil,
          page_title: "Lens Not Found"
        )

      {:ok, lens} ->
        subgraph = Perspective.get_subgraph(perspective_id)

        socket = assign(socket, lens: lens, subgraph: subgraph)

        case Perspective.set_current_vertex(perspective_id, vertex_id) do
          {:error, :vertex_not_found} ->
            assign(socket,
              vertex: nil,
              content: nil,
              contents: [],
              breadcrumbs: [],
              page_title: "Vertex Not Found"
            )

          {:ok, vertex} ->
            breadcrumbs = Perspective.get_breadcrumbs(perspective_id)
            contents = Perspective.get_contents(perspective_id)

            socket =
              socket
              |> assign(vertex: vertex, contents: contents, breadcrumbs: breadcrumbs)
              |> assign_async(
                :zoom_subgraph,
                fn ->
                  {:ok, %{zoom_subgraph: Perspective.get_zoom_subgraph(perspective_id)}}
                end,
                reset: true
              )
              |> update_page_title()

            # credo:disable-for-next-line Credo.Check.Refactor.Nesting
            case Perspective.get_content(perspective_id, content_id) do
              {:error, :content_not_found} ->
                assign(socket, content: nil, page_title: "Content Not Found")

              {:ok, content} ->
                assign(socket, content: content)
            end
        end
    end
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <%= if !@loaded? do %>
      <.splash_screen />
    <% else %>
      <.flash_group flash={@flash} />
      <%= case @lens do %>
        <% nil -> %>
          <.lens_not_found_error prefix={@prefix} />
        <% lens -> %>
          <article class="layout-container bg-base-light-50 dark:bg-base-dark-900 text-base-light-900 dark:text-base-dark-100">
            <.header
              socket={@socket}
              prefix={@prefix}
              lens={@lens}
              theme={@theme}
              clarity_pid={@clarity_pid}
              class="header z-10"
            />

            <nav class={"navigation bg-base-light-100 dark:bg-base-dark-800 border-r border-base-light-300 dark:border-base-dark-700 p-4 md:block #{if @show_navigation, do: "block", else: "hidden"}"}>
              <.live_component
                module={Clarity.TreeComponent}
                id="navigation-tree"
                graph={@subgraph}
                active_vertex={@vertex}
                breadcrumbs={@breadcrumbs}
                prefix={@prefix}
                lens={lens}
              />
            </nav>

            <%= if @vertex do %>
              <div class="title bg-base-light-50 dark:bg-base-dark-900 border-b border-base-light-300 dark:border-base-dark-700 px-4 py-3 flex items-center">
                <nav class="breadcrumbs mr-3">
                  <ol class="flex flex-wrap text-xs text-base-light-600 dark:text-base-dark-400 space-x-1">
                    <%= for {breadcrumb, idx} <- Enum.with_index(Enum.drop(@breadcrumbs, -1)) do %>
                      <li class="flex items-center">
                        <span :if={idx > 0} class="mx-1 text-base-light-500 dark:text-base-dark-600">
                          →
                        </span>
                        <.link
                          patch={Path.join([@prefix, @lens.id, Vertex.id(breadcrumb)])}
                          class="hover:text-primary-light dark:hover:text-primary-dark transition-colors"
                        >
                          {Vertex.name(breadcrumb)}
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
                  {Vertex.name(@vertex)}
                </h1>
              </div>
              <.tabs
                contents={@contents}
                content={@content}
                prefix={@prefix}
                vertex={@vertex}
                lens={lens}
              />
              <.render_content
                content={@content}
                vertex={@vertex}
                perspective_pid={@perspective_pid}
                socket={@socket}
                theme={@theme}
                prefix={@prefix}
                lens={lens}
                zoom_subgraph={@zoom_subgraph}
              />
            <% else %>
              <.vertex_not_found_error prefix={@prefix} lens={lens} />
            <% end %>
          </article>
          <.live_component
            module={Clarity.TooltipComponent}
            id="tooltips"
            graph={@subgraph}
            breadcrumbs={@breadcrumbs}
            prefix={@prefix}
            lens={@lens}
          />
      <% end %>
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

  @impl Phoenix.LiveView
  def handle_info({:clarity, event}, socket) when event in [:work_started, :work_completed] do
    {:noreply, handle_routing(socket, socket.assigns.params, &push_patch/2)}
  end

  def handle_info({:flash, kind, message}, socket) do
    {:noreply, put_flash(socket, kind, message)}
  end

  def handle_info(:refresh_interval, socket) do
    # Only refresh if work is in progress to avoid unnecessary calls
    socket =
      if socket.assigns.clarity.status == :working do
        handle_routing(socket, socket.assigns.params, &push_patch/2)
      else
        socket
      end

    Process.send_after(self(), :refresh_interval, to_timeout(second: 1))

    {:noreply, socket}
  end

  @spec render_content(assigns :: Socket.assigns()) :: Rendered.t()
  defp render_content(assigns) do
    ~H"""
    <.async_result :let={zoom_subgraph} assign={@zoom_subgraph}>
      <:loading>
        <.loading_spinner class="content" />
      </:loading>
      <% content_props = %{
        theme: @theme,
        zoom_subgraph: zoom_subgraph
      } %>
      <%= cond do %>
        <% @content == nil -> %>
          <.content_not_found_error />
        <% @content.live_component? -> %>
          <.live_component
            module={@content.provider}
            id="content-view"
            vertex={@vertex}
            lens={@lens}
            perspective_pid={@perspective_pid}
            {content_props}
          />
        <% @content.live_view? -> %>
          {live_render(@socket, @content.provider,
            id: "content-view",
            session: %{
              "vertex" => @vertex,
              "lens" => @lens,
              "perspective_pid" => @perspective_pid
            },
            container: {:div, class: "content"}
          )}
        <% true -> %>
          <%= case @content.render_static do %>
            <% {:mermaid, content} -> %>
              <.mermaid graph={content.(content_props)} class="content p-4" id="content-view-mermaid" />
            <% {:viz, content} -> %>
              <.viz graph={content.(content_props)} class="content p-4" id="content-view-viz" />
            <% {:markdown, content} -> %>
              <section class="content w-full flex justify-center">
                <.markdown
                  content={content.(content_props)}
                  class="p-4 max-w-[100ch] w-full"
                  prefix={@prefix}
                  lens={@lens}
                />
              </section>
          <% end %>
      <% end %>
    </.async_result>
    """
  end

  @spec update_page_title(Socket.t()) :: Socket.t()
  defp update_page_title(socket) do
    page_title =
      socket.assigns.breadcrumbs
      |> Enum.drop(1)
      |> Enum.reverse()
      |> Enum.map_join(" · ", &Vertex.name/1)

    assign(socket, page_title: page_title)
  end

  @spec get_first_content_id(pid()) :: String.t()
  defp get_first_content_id(perspective_pid) do
    [%{id: id} | _] = Perspective.get_contents(perspective_pid)

    id
  end
end
