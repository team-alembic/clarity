defmodule AshAtlas.CoreComponents do
  @moduledoc false

  use Phoenix.Component

  import Phoenix.HTML

  alias AshAtlas.Vertex

  attr :breadcrumbs, :list, required: true, doc: "List of breadcrumb vertices"
  attr :prefix, :string, default: "/", doc: "The URL prefix for links"
  attr :class, :string, default: "", doc: "CSS classes to apply to the header container"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the header container"

  def header(assigns) do
    ~H"""
    <header class={"flex items-center px-6 py-4 bg-gray-800 shadow-md #{@class}"} {@rest}>
      <.link patch={@prefix <> "/root/graph"} class="mr-4">
        <img src={ash_logo()} alt="Ash Logo" class="h-8 w-8" />
      </.link>
      <h1 class="text-2xl font-bold tracking-tight flex-1 truncate">
        <.link patch={@prefix <> "/root/graph"} class="mr-4">
          Ash Atlas
        </.link>
      </h1>

      <nav id="breadcrumbs">
        <ol class="flex flex-wrap text-sm text-gray-400 space-x-2">
          <%= for {breadcrumb, idx} <- Enum.with_index(@breadcrumbs), idx > 0 do %>
            <li class="flex items-center">
              <span :if={idx > 1} class="mx-2 text-gray-600">/</span>
              <.link
                patch={"#{@prefix}/#{AshAtlas.Vertex.unique_id(breadcrumb)}/graph"}
                class="hover:text-ash-400 transition-colors"
              >
                <.vertex_name vertex={breadcrumb} />
              </.link>
            </li>
          <% end %>
        </ol>
      </nav>
    </header>
    """
  end

  attr :tree, :map, required: true, doc: "The navigation tree structure"
  attr :prefix, :string, default: "/", doc: "The URL prefix for links"
  attr :current, :any, required: true, doc: "The currently selected node in the tree"
  attr :breadcrumbs, :list, required: true, doc: "List of breadcrumb vertices"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the navigation container"

  def navigation(assigns) do
    ~H"""
    <nav {@rest}>
      <.navigation_tree tree={@tree} prefix={@prefix} current={@current} breadcrumbs={@breadcrumbs} />
    </nav>
    """
  end

  attr :tree, :map, required: true, doc: "The navigation tree structure"
  attr :prefix, :string, default: "/", doc: "The URL prefix for links"
  attr :current, :any, required: true, doc: "The currently selected node in the tree"
  attr :breadcrumbs, :list, required: true, doc: "List of breadcrumb vertices"

  defp navigation_tree(assigns) do
    ~H"""
    <details
      :for={{label, child_vertices} <- @tree.children}
      :if={label != :content}
      open={Enum.any?(@breadcrumbs, &(&1 == @tree.node))}
    >
      <summary class="cursor-pointer select-none text-gray-400 hover:text-ash-400 px-2 py-1 rounded-sm group-open:bg-gray-700 transition-colors">
        <span>{label}</span>
      </summary>
      <ul class="border-l border-gray-700 pl-2 space-y-1">
        <li :for={child <- child_vertices}>
          <.navigation_node
            tree={child}
            prefix={@prefix}
            current={@current}
            breadcrumbs={@breadcrumbs}
          />
        </li>
      </ul>
    </details>
    """
  end

  attr :tree, :map, required: true, doc: "The navigation tree structure"
  attr :prefix, :string, default: "/", doc: "The URL prefix for links"
  attr :current, :any, required: true, doc: "The currently selected node in the tree"
  attr :breadcrumbs, :list, required: true, doc: "List of breadcrumb vertices"

  defp navigation_node(assigns) do
    ~H"""
    <.link
      patch={"#{@prefix}/#{AshAtlas.Vertex.unique_id(@tree.node)}/graph"}
      class={
        "block px-2 py-1 rounded-sm hover:bg-gray-700 hover:text-ash-400 transition-colors font-medium" <>
        if @tree.node == @current, do: " bg-red-700 text-ash-400", else: ""
      }
    >
      <.vertex_name vertex={@tree.node} />
    </.link>
    <%= if @tree.children != %{} do %>
      <div class="ml-4 group">
        <.navigation_tree tree={@tree} prefix={@prefix} current={@current} breadcrumbs={@breadcrumbs} />
      </div>
    <% end %>
    """
  end

  attr :vertex, :any, required: true, doc: "The vertex to render"

  def vertex_name(assigns) do
    ~H"""
    {Vertex.render_name(@vertex)}
    """
  end

  attr :id, :string, required: true, doc: "The unique ID for the visualization element"
  attr :graph, :string, required: true, doc: "The graph data in DOT language format"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the graph container"

  def viz(assigns) do
    ~H"""
    <pre phx-hook="Viz" id={@id} data-graph={@graph} phx-update="ignore" {@rest}></pre>
    """
  end

  attr :id, :string, required: true, doc: "The unique ID for the mermaid visualization"
  attr :graph, :string, required: true, doc: "The mermaid graph definition in string format"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the graph container"

  def mermaid(assigns) do
    ~H"""
    <pre phx-hook="Mermaid" id={@id} data-graph={@graph} phx-update="ignore" {@rest}></pre>
    """
  end

  attr :content, :string, required: true, doc: "The markdown content to render"
  attr :class, :string, default: "", doc: "CSS classes to apply to the markdown container"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the markdown container"

  def markdown(assigns) do
    ~H"""
    <div class={"prose prose-invert #{@class}"} {@rest}>
      {case Earmark.as_html(@content) do
        {:ok, html, _} -> raw(html)
        {:error, reason, _} -> "<p>Error rendering markdown: #{reason}</p>"
      end}
    </div>
    """
  end

  logo_path = Path.join(__DIR__, "../../../priv/static/images/ash_logo_orange.svg")
  @external_resource logo_path
  @ash_logo "data:image/svg+xml;base64," <> Base.encode64(File.read!(logo_path))
  defp ash_logo, do: @ash_logo
end
