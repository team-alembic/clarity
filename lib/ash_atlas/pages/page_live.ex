defmodule AshAtlas.PageLive do
  @moduledoc false

  use AshAtlas.Web, :live_view

  alias AshAtlas.Vertex
  alias Phoenix.LiveView.Rendered
  alias Phoenix.LiveView.Socket

  @impl Phoenix.LiveView
  def mount(%{"vertex" => vertex, "content" => content} = _params, _session, socket) do
    atlas = AshAtlas.get()
    vertex = Map.fetch!(atlas.vertices, vertex)

    {:ok,
     socket
     |> assign(atlas: atlas)
     |> update_dynamics(vertex, content)}
  end

  def mount(params, %{"prefix" => prefix} = _session, socket) when params == %{} do
    {:ok, push_navigate(socket, to: prefix <> "/root/graph")}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"vertex" => vertex, "content" => content}, _url, socket) do
    vertex = Map.fetch!(socket.assigns.atlas.vertices, vertex)
    {:noreply, update_dynamics(socket, vertex, content)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-900 text-gray-100 flex flex-col">
      <.header breadcrumbs={@breadcrumbs} prefix={@prefix} asset_path={@asset_path} class="z-10" />

      <div class="flex flex-1">
        <!-- TODO: Make overflow y auto work --->
        <.navigation
          tree={@atlas.tree}
          prefix={@prefix}
          current={@current_vertex}
          breadcrumbs={@breadcrumbs}
          class="w-64 bg-gray-800 border-r border-gray-700 p-4 overflow-auto"
        />

        <main class="flex-1 flex flex-col overflow-auto">
          <.tabs
            contents={@contents}
            current_content={@current_content}
            prefix={@prefix}
            current_vertex={@current_vertex}
          />
          <.render_content content={@current_content} socket={@socket} />
        </main>
      </div>
    </div>
    """
  end

  @impl Phoenix.LiveView
  def handle_event("viz:click", %{"id" => id}, socket) do
    {:noreply, push_patch(socket, to: "#{socket.assigns.prefix}/#{id}/graph")}
  end

  @spec tabs(assigns :: Socket.assigns()) :: Rendered.t()
  defp tabs(assigns) do
    ~H"""
    <nav class="border-b border-gray-700 bg-gray-900 px-4">
      <ul class="flex space-x-2">
        <li :for={content <- @contents}>
          <.link
            patch={"#{@prefix}/#{AshAtlas.Vertex.unique_id(@current_vertex)}/#{content.id}"}
            class={
            "inline-block px-4 py-2 rounded-t-md font-medium transition-colors " <>
            if content.id == @current_content.id,
              do: "bg-gray-800 text-ash-400 border-b-2 border-ash-400",
              else: "text-gray-400 hover:text-ash-400 hover:bg-gray-800"
            }
          >
            {content.name}
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
        <.mermaid graph={content.()} class="flex-1 relative" id="content-view" />
      <% {:mermaid, content} -> %>
        <.mermaid graph={content} class="flex-1 relative" id="content-view" />
      <% {:viz, content} when is_function(content, 0) -> %>
        <.viz graph={content.()} class="flex-1 relative" id="content-view" />
      <% {:viz, content} -> %>
        <.viz graph={content} class="flex-1 relative" id="content-view" />
      <% {:markdown, content} when is_function(content, 0) -> %>
        <.markdown content={content.()} class="p-4" />
      <% {:markdown, content} -> %>
        <.markdown content={content} class="p-4" />
      <% {:live_view, {module, session}} -> %>
        {live_render(@socket, module, id: "content-view", session: session)}
    <% end %>
    """
  end

  @spec update_dynamics(
          socket :: Socket.t(),
          current_vertex :: Vertex.t(),
          current_content :: String.t()
        ) :: Socket.t()
  defp update_dynamics(socket, current_vertex, current_content) do
    %AshAtlas{graph: graph, root: root} = socket.assigns.atlas

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
           fn ->
             graph
             |> AshAtlas.GraphUtil.subgraph_within_steps(current_vertex, 2, 1)
             |> AshAtlas.Graph.to_dot(theme: :dark)
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
