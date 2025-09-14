defmodule Clarity.PageLive do
  @moduledoc false

  use Clarity.Web, :live_view

  alias Clarity.Vertex
  alias Phoenix.LiveView.Rendered
  alias Phoenix.LiveView.Socket

  @impl Phoenix.LiveView
  def mount(%{"vertex" => vertex, "content" => content} = _params, _session, socket) do
    clarity = Clarity.get()
    vertex = Map.fetch!(clarity.vertices, vertex)

    {:ok,
     socket
     |> assign(clarity: clarity, show_navigation: false, refreshing: false)
     |> update_dynamics(vertex, content)}
  end

  def mount(params, %{"prefix" => prefix} = _session, socket) when params == %{} do
    {:ok, push_navigate(socket, to: Path.join([prefix, "root", "graph"]))}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"vertex" => vertex, "content" => content}, _url, socket) do
    vertex = Map.fetch!(socket.assigns.clarity.vertices, vertex)
    {:noreply, socket |> assign(show_navigation: false) |> update_dynamics(vertex, content)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <article class="layout-container bg-base-light-50 dark:bg-base-dark-900 text-base-light-900 dark:text-base-dark-100">
      <.header
        breadcrumbs={@breadcrumbs}
        prefix={@prefix}
        theme={@theme}
        refreshing={@refreshing}
        class="header z-10"
      />

      <.navigation
        tree={@clarity.tree}
        prefix={@prefix}
        current={@current_vertex}
        breadcrumbs={@breadcrumbs}
        class={"navigation bg-base-light-100 dark:bg-base-dark-800 border-r border-base-light-300 dark:border-base-dark-700 p-4 md:block #{if @show_navigation, do: "block", else: "hidden"}"}
      />

      <.tabs
        contents={@contents}
        current_content={@current_content}
        prefix={@prefix}
        current_vertex={@current_vertex}
      />
      <.render_content content={@current_content} socket={@socket} theme={@theme} />
    </article>
    <.render_tooltips clarity={@clarity} />
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
    socket = assign(socket, refreshing: true)
    {:noreply, start_async(socket, :refresh_clarity, fn -> Clarity.update() end)}
  end

  @impl Phoenix.LiveView
  def handle_async(:refresh_clarity, {:ok, new_clarity}, socket) do
    socket =
      socket
      |> assign(clarity: new_clarity, refreshing: false)
      |> update_dynamics(socket.assigns.current_vertex, socket.assigns.current_content.id)

    {:noreply, socket}
  end

  def handle_async(:refresh_clarity, {:exit, reason}, socket) do
    socket =
      socket
      |> assign(refreshing: false)
      |> put_flash(:error, "Failed to refresh: #{inspect(reason)}")

    {:noreply, socket}
  end

  @spec tabs(assigns :: Socket.assigns()) :: Rendered.t()
  defp tabs(assigns) do
    ~H"""
    <nav class="tabs border-b border-base-light-300 dark:border-base-dark-700 bg-base-light-100 dark:bg-base-dark-900 px-4">
      <ul class="flex space-x-2">
        <li :for={content <- @contents}>
          <.link
            patch={Path.join([@prefix, Clarity.Vertex.unique_id(@current_vertex), content.id])}
            class={
            "inline-block px-4 py-2 rounded-t-md font-medium transition-colors " <>
            if content.id == @current_content.id,
              do: "bg-base-light-200 dark:bg-base-dark-800 text-primary-light dark:text-primary-dark border-b-2 border-primary-light dark:border-primary-dark",
              else: "text-base-light-600 dark:text-base-dark-400 hover:text-primary-light dark:hover:text-primary-dark hover:bg-base-light-200 dark:hover:bg-base-dark-800"
            }
          >
            <.vertex_name vertex={content} />
          </.link>
        </li>
      </ul>
    </nav>
    """
  end

  @spec render_content(assigns :: Socket.assigns()) :: Rendered.t()
  defp render_content(assigns) do
    ~H"""
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
    """
  end

  @spec render_tooltips(assigns :: Socket.assigns()) :: Rendered.t()
  defp render_tooltips(assigns) do
    ~H"""
    <%= for %mod{} = vertex <- :digraph.vertices(@clarity.graph),
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

  @spec update_dynamics(
          socket :: Socket.t(),
          current_vertex :: Vertex.t(),
          current_content :: String.t()
        ) :: Socket.t()
  defp update_dynamics(socket, current_vertex, current_content) do
    %Clarity{graph: graph, root: root} = socket.assigns.clarity

    breadcrumbs =
      graph
      |> :digraph.get_short_path(root, current_vertex)
      |> case do
        false -> [current_vertex]
        path -> path
      end

    contents =
      graph
      |> :digraph.out_edges(current_vertex)
      |> Enum.map(&:digraph.edge(graph, &1))
      |> Enum.filter(fn {_, _, _, label} -> label == :content end)
      |> Enum.map(fn {_, _, to, _} -> to end)

    contents = [
      %Vertex.Content{
        id: "graph",
        name: "Graph Navigation",
        content:
          {:viz,
           fn %{theme: theme} ->
             graph
             |> Clarity.GraphUtil.subgraph_within_steps(current_vertex, 2, 1)
             |> Clarity.Graph.to_dot(theme: theme, highlight: current_vertex)
           end}
      }
      | contents
    ]

    current_content =
      Enum.find(contents, List.first(contents), fn content -> content.id == current_content end)

    page_title =
      breadcrumbs
      |> Enum.drop(1)
      |> Enum.reverse()
      |> Enum.map_join(" · ", &Vertex.render_name/1)

    assign(socket,
      current_vertex: current_vertex,
      breadcrumbs: breadcrumbs,
      contents: contents,
      current_content: current_content,
      page_title: page_title
    )
  end
end
