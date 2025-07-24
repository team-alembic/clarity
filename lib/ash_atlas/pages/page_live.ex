defmodule AshAtlas.PageLive do
  @moduledoc false
  use AshAtlas.Web, :live_view

  alias AshAtlas.Tree.Node

  logo_path = Path.join(__DIR__, "../../../priv/static/images/ash_logo_orange.svg")
  @external_resource logo_path
  @ash_logo "data:image/svg+xml;base64," <> Base.encode64(File.read!(logo_path))

  @impl Phoenix.LiveView
  def mount(
        %{"node" => node, "content" => content} = _params,
        %{
          "prefix" => prefix
        } = session,
        socket
      ) do
    graph = AshAtlas.graph()
    tree = AshAtlas.tree(graph)

    node = AshAtlas.node_by_unique_id(graph, node)

    prefix =
      case prefix do
        "/" ->
          session["request_path"]

        _ ->
          request_path = session["request_path"]
          [scope, _] = String.split(request_path, prefix)
          scope <> prefix
      end

    {:ok, assign(socket, graph: graph, prefix: prefix, tree: tree) |> update_dynamics(node, content)}
  end

  def mount(params, %{"prefix" => prefix}, socket) when params == %{} do
    {:ok, push_navigate(socket, to: prefix <> "/root/graph")}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"node" => node, "content" => content}, _url, socket) do
    node = AshAtlas.node_by_unique_id(socket.assigns.graph, node)
    {:noreply, update_dynamics(socket, node, content)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-900 text-gray-100 flex flex-col">
      <header class="flex items-center px-6 py-4 bg-gray-800 shadow-md z-10">
        <img src={ash_logo()} alt="Ash Logo" class="h-8 w-8 mr-4" />
        <h1 class="text-2xl font-bold tracking-tight flex-1 truncate">
          Ash Atlas
        </h1>

        <nav id="breadcrumbs">
          <ol class="flex flex-wrap text-sm text-gray-400 space-x-2">
            <%= for {breadcrumb, idx} <- Enum.with_index(@breadcrumbs) do %>
              <li class="flex items-center">
                <span :if={idx > 0} class="mx-2 text-gray-600">/</span>
                <.link
                  patch={"#{@prefix}/#{AshAtlas.Tree.Node.unique_id(breadcrumb)}/graph"}
                  class="hover:text-ash-400 transition-colors"
                >
                  <.render_node node={breadcrumb} />
                </.link>
              </li>
            <% end %>
          </ol>
        </nav>
      </header>

      <div class="flex flex-1">
        <!-- TODO: Make overflow y auto work --->
        <aside class="w-64 bg-gray-800 border-r border-gray-700 p-4 overflow-auto">
          <.render_navigation_tree
            tree={@tree}
            prefix={@prefix}
            current_node={@current_node}
            breadcrumbs={@breadcrumbs}
          />
        </aside>

        <main class="flex-1 flex flex-col overflow-auto">
            <nav class="border-b border-gray-700 bg-gray-900 px-4">
            <ul class="flex space-x-2">
              <li :for={content <- @contents}>
                <.link
                  patch={"#{@prefix}/#{AshAtlas.Tree.Node.unique_id(@current_node)}/#{content.id}"}
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

  defp render_node(assigns) do
    ~H"""
    {Node.render_name(assigns.node)}
    """
  end

  defp render_navigation_tree(assigns) do
    ~H"""
    <details :for={{label, child_nodes} <- @tree.children} :if={label != :content} open={Enum.any?(@breadcrumbs, &(&1 == @tree.vertex))}>
      <summary class="cursor-pointer select-none text-gray-400 hover:text-ash-400 px-2 py-1 rounded-sm group-open:bg-gray-700 transition-colors">
        <span>{label}</span>
      </summary>
      <ul class="border-l border-gray-700 pl-2 space-y-1">
        <li :for={child <- child_nodes}>
          <.render_navigation_node
            tree={child}
            prefix={@prefix}
            current_node={@current_node}
            breadcrumbs={@breadcrumbs}
          />
        </li>
      </ul>
    </details>
    """
  end

  defp render_navigation_node(assigns) do
    ~H"""
    <.link
      patch={"#{@prefix}/#{AshAtlas.Tree.Node.unique_id(@tree.vertex)}/graph"}
      class={
        "block px-2 py-1 rounded-sm hover:bg-gray-700 hover:text-ash-400 transition-colors font-medium" <>
        if @tree.vertex == @current_node, do: " bg-red-700 text-ash-400", else: ""
      }
    >
      <.render_node node={@tree.vertex} />
    </.link>
    <%= if @tree.children != %{} do %>
      <div class="ml-4 group">
        <.render_navigation_tree
          tree={@tree}
          prefix={@prefix}
          current_node={@current_node}
          breadcrumbs={@breadcrumbs} />
      </div>
    <% end %>
    """
  end

  defp render_content(assigns) do
    ~H"""
    <%= case @content.content do %>
      <% {:mermaid, content} when is_function(content, 0) -> %>
        <.mermaid graph={content.()} />
      <% {:mermaid, content} -> %>
        <.mermaid graph={content} />
      <% {:viz, content} when is_function(content, 0) -> %>
        <.viz graph={content.()} />
      <% {:viz, content} -> %>
        <.viz graph={content} />
      <% {:markdown, content} when is_function(content, 0) -> %>
        <.markdown content={content.()} />
      <% {:markdown, content} -> %>
        <.markdown content={content} />
      <% {:live_view, {module, session}} -> %>
        {live_render(@socket, module, id: "content-view", session: session)}
    <% end %>
    """
  end

  defp viz(assigns) do
    ~H"""
    <pre phx-hook="Viz" id="explorer" data-graph={@graph} class="flex-1 relative" phx-update="ignore"></pre>
    """
  end

  defp mermaid(assigns) do
    ~H"""
    <pre phx-hook="Mermaid" id="content-mermaid" data-graph={@graph} class="flex-1 relative" phx-update="ignore"></pre>
    """
  end

  defp markdown(assigns) do
    ~H"""
    <!-- TODO: Style markdown -->
    <div class="markdown-body p-4">
      <%= case Earmark.as_html(@content) do
        {:ok, html, _} -> raw(html)
        {:error, reason, _} -> "<p>Error rendering markdown: #{reason}</p>"
      end %>
    </div>
    """
  end

  defp update_dynamics(socket, node, current_content) do
    subgraph = AshAtlas.subgraph(socket.assigns.graph, node, 2, 1)

    breadcrumbs =
      socket.assigns.graph
      |> :digraph.get_short_path(
        AshAtlas.node_by_unique_id(socket.assigns.graph, "root"),
        node
      )
      |> case do
        false -> [node]
        path -> path
      end

    contents = socket.assigns.graph
    |> :digraph.out_edges(node)
    |> Enum.map(&:digraph.edge(socket.assigns.graph, &1))
    |> Enum.filter(fn {_, _, _, label} -> label == :content end)
    |> Enum.map(fn {_, _, to, _} -> to end)

    contents = [
      %Node.Content{
        id: "graph",
        name: "Graph Navigation",
        content: {:viz, fn -> AshAtlas.Graph.to_dot(subgraph) end}
      } | contents
    ]

    current_content = Enum.find(contents, List.first(contents), fn content -> content.id == current_content end)

    assign(socket, current_node: node, subgraph: subgraph, breadcrumbs: breadcrumbs, contents: contents, current_content: current_content)
  end

  defp ash_logo, do: @ash_logo
end
