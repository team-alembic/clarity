defmodule AshAtlas.CoreComponents do
  @moduledoc false

  use Phoenix.Component

  import AshAtlas.Router, only: [__asset_path__: 2]
  import Phoenix.HTML

  alias AshAtlas.Vertex
  alias Phoenix.LiveView.Rendered
  alias Phoenix.LiveView.Socket

  attr :breadcrumbs, :list, required: true, doc: "List of breadcrumb vertices"
  attr :prefix, :string, default: "/", doc: "The URL prefix for links"
  attr :asset_path, :string, default: "/", doc: "The path to static assets"
  attr :class, :string, default: "", doc: "CSS classes to apply to the header container"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the header container"

  @spec header(assigns :: Socket.assigns()) :: Rendered.t()
  def header(assigns) do
    ~H"""
    <header class={"flex items-center px-6 py-4 bg-gray-800 shadow-md #{@class}"} {@rest}>
      <.link patch={Path.join([@prefix, "root", "graph"])} class="mr-4">
        <img
          src={__asset_path__(@asset_path, "images/ash_logo_orange.svg")}
          alt="Ash Logo"
          class="h-8 w-8"
        />
      </.link>
      <h1 class="text-2xl font-bold tracking-tight flex-1 truncate">
        <.link patch={Path.join([@prefix, "root", "graph"])} class="mr-4">
          Ash Atlas
        </.link>
      </h1>

      <nav id="breadcrumbs" class="hidden md:block">
        <ol class="flex flex-wrap text-sm text-gray-400 space-x-2">
          <%= for {breadcrumb, idx} <- Enum.with_index(@breadcrumbs), idx > 0 do %>
            <li class="flex items-center">
              <span :if={idx > 1} class="mx-2 text-gray-600">/</span>
              <.link
                patch={Path.join([@prefix, AshAtlas.Vertex.unique_id(breadcrumb), "graph"])}
                class="hover:text-ash-400 transition-colors"
              >
                <.vertex_name vertex={breadcrumb} />
              </.link>
            </li>
          <% end %>
        </ol>
      </nav>

      <button
        type="button"
        class="inline-flex items-center justify-center p-2 rounded-md text-gray-400 hover:text-white hover:bg-gray-700 md:hidden"
        phx-click="toggle_navigation"
        aria-label="Toggle navigation"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          fill="none"
          viewBox="0 0 24 24"
          stroke-width="1.5"
          stroke="currentColor"
          class="size-6"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5"
          />
        </svg>
      </button>
    </header>
    """
  end

  attr :tree, :map, required: true, doc: "The navigation tree structure"
  attr :prefix, :string, default: "/", doc: "The URL prefix for links"
  attr :current, :any, required: true, doc: "The currently selected node in the tree"
  attr :breadcrumbs, :list, required: true, doc: "List of breadcrumb vertices"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the navigation container"

  @spec navigation(assigns :: Socket.assigns()) :: Rendered.t()
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

  @spec navigation_tree(assigns :: Socket.assigns()) :: Rendered.t()
  defp navigation_tree(assigns) do
    ~H"""
    <div :for={{label, child_vertices} <- @tree.children} :if={label != :content}>
      <span class="cursor-pointer select-none text-gray-400 hover:text-ash-400 px-2 py-1 rounded-sm group-open:bg-gray-700 transition-colors">
        {label}
      </span>
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
    </div>
    """
  end

  attr :tree, :map, required: true, doc: "The navigation tree structure"
  attr :prefix, :string, default: "/", doc: "The URL prefix for links"
  attr :current, :any, required: true, doc: "The currently selected node in the tree"
  attr :breadcrumbs, :list, required: true, doc: "List of breadcrumb vertices"

  @spec navigation_node(assigns :: Socket.assigns()) :: Rendered.t()
  defp navigation_node(assigns) do
    ~H"""
    <%= if Enum.any?(@tree.children, &(elem(&1, 0) != :content)) do %>
      <details open={Enum.any?(@breadcrumbs, &(&1 == @tree.node))}>
        <summary>
          <.link
            patch={Path.join([@prefix, AshAtlas.Vertex.unique_id(@tree.node), "graph"])}
            class={
              "inline px-2 py-1 rounded-sm hover:bg-gray-700 hover:text-ash-400 transition-colors font-medium" <>
              if @tree.node == @current, do: " bg-red-700 text-ash-400", else: ""
            }
          >
            <.vertex_name vertex={@tree.node} />
          </.link>
        </summary>
        <div class="ml-4 group">
          <.navigation_tree
            tree={@tree}
            prefix={@prefix}
            current={@current}
            breadcrumbs={@breadcrumbs}
          />
        </div>
      </details>
    <% else %>
      <.link
        patch={Path.join([@prefix, AshAtlas.Vertex.unique_id(@tree.node), "graph"])}
        class={
              "inline px-2 py-1 rounded-sm hover:bg-gray-700 hover:text-ash-400 transition-colors font-medium" <>
              if @tree.node == @current, do: " bg-red-700 text-ash-400", else: ""
            }
      >
        <.vertex_name vertex={@tree.node} />
      </.link>
    <% end %>
    """
  end

  attr :vertex, :any, required: true, doc: "The vertex to render"

  @spec vertex_name(assigns :: Socket.assigns()) :: Rendered.t()
  def vertex_name(assigns) do
    ~H"""
    <span data-tooltip={"tooltip-#{Vertex.unique_id(@vertex)}"}>{Vertex.render_name(@vertex)}</span>
    """
  end

  attr :id, :string, required: true, doc: "The unique ID for the visualization element"
  attr :graph, :string, required: true, doc: "The graph data in DOT language format"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the graph container"

  @spec viz(assigns :: Socket.assigns()) :: Rendered.t()
  def viz(assigns) do
    ~H"""
    <pre phx-hook="Viz" id={@id} data-graph={@graph} phx-update="ignore" {@rest}></pre>
    """
  end

  attr :id, :string, required: true, doc: "The unique ID for the mermaid visualization"
  attr :graph, :string, required: true, doc: "The mermaid graph definition in string format"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the graph container"

  @spec mermaid(assigns :: Socket.assigns()) :: Rendered.t()
  def mermaid(assigns) do
    ~H"""
    <pre phx-hook="Mermaid" id={@id} data-graph={@graph} phx-update="ignore" {@rest}></pre>
    """
  end

  attr :content, :string, required: true, doc: "The markdown content to render"
  attr :class, :string, default: "", doc: "CSS classes to apply to the markdown container"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the markdown container"

  @spec markdown(assigns :: Socket.assigns()) :: Rendered.t()
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
end
