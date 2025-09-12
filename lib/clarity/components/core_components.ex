defmodule Clarity.CoreComponents do
  @moduledoc false

  use Phoenix.Component

  import Clarity.Router, only: [__asset_path__: 2]
  import Phoenix.HTML

  alias Clarity.Vertex
  alias Phoenix.LiveView.Rendered
  alias Phoenix.LiveView.Socket

  attr :breadcrumbs, :list, required: true, doc: "List of breadcrumb vertices"
  attr :prefix, :string, default: "/", doc: "The URL prefix for links"
  attr :asset_path, :string, default: "/", doc: "The path to static assets"
  attr :theme, :atom, required: true, doc: "Current theme (:dark or :light)"
  attr :refreshing, :boolean, default: false, doc: "Whether a refresh is in progress"
  attr :class, :string, default: "", doc: "CSS classes to apply to the header container"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the header container"

  @spec header(assigns :: Socket.assigns()) :: Rendered.t()
  def header(assigns) do
    ~H"""
    <header
      class={"flex items-center px-6 py-4 bg-base-light-100 dark:bg-base-dark-800 shadow-md #{@class}"}
      {@rest}
    >
      <.link patch={Path.join([@prefix, "root", "graph"])} class="mr-4">
        <img
          src={__asset_path__(@asset_path, "images/ash_logo_orange.svg")}
          alt="Ash Logo"
          class="h-8 w-8"
        />
      </.link>
      <h1 class="text-2xl font-bold tracking-tight flex-1 truncate text-base-light-900 dark:text-base-dark-50">
        <.link patch={Path.join([@prefix, "root", "graph"])} class="mr-4">
          Clarity
        </.link>
      </h1>

      <nav id="breadcrumbs" class="hidden md:block">
        <ol class="flex flex-wrap text-sm text-base-light-600 dark:text-base-dark-400 space-x-2">
          <%= for {breadcrumb, idx} <- Enum.with_index(@breadcrumbs), idx > 0 do %>
            <li class="flex items-center">
              <span :if={idx > 1} class="mx-2 text-base-light-500 dark:text-base-dark-600">/</span>
              <.link
                patch={Path.join([@prefix, Clarity.Vertex.unique_id(breadcrumb), "graph"])}
                class="hover:text-primary-light dark:hover:text-primary-dark transition-colors"
              >
                <.vertex_name vertex={breadcrumb} />
              </.link>
            </li>
          <% end %>
        </ol>
      </nav>

      <div class="flex items-center space-x-2 md:ml-6">
        <.refresh_button refreshing={@refreshing} />
        <.theme_toggle id="header-theme-toggle" theme={@theme} />
        <button
          type="button"
          class="inline-flex items-center justify-center p-2 rounded-md text-base-light-600 dark:text-base-dark-400 hover:text-base-light-900 dark:hover:text-base-dark-100 hover:bg-base-light-200 dark:hover:bg-base-dark-700 md:hidden"
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
      </div>
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
      <span class="cursor-pointer select-none text-base-light-600 dark:text-base-dark-400 hover:text-primary-light dark:hover:text-primary-dark px-2 py-1 rounded-sm group-open:bg-base-light-200 dark:group-open:bg-base-dark-700 transition-colors">
        {label}
      </span>
      <ul class="border-l border-base-light-300 dark:border-base-dark-700 pl-2 space-y-1">
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
            patch={Path.join([@prefix, Clarity.Vertex.unique_id(@tree.node), "graph"])}
            class={
              "inline px-2 py-1 rounded-sm hover:bg-base-light-200 dark:hover:bg-base-dark-700 hover:text-primary-light dark:hover:text-primary-dark transition-colors font-medium" <>
              if @tree.node == @current, do: " bg-primary-light dark:bg-primary-dark text-white dark:text-base-dark-900", else: ""
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
        patch={Path.join([@prefix, Clarity.Vertex.unique_id(@tree.node), "graph"])}
        class={
              "inline px-2 py-1 rounded-sm hover:bg-base-light-200 dark:hover:bg-base-dark-700 hover:text-primary-light dark:hover:text-primary-dark transition-colors font-medium" <>
              if @tree.node == @current, do: " bg-primary-light dark:bg-primary-dark text-white dark:text-base-dark-900", else: ""
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
    <div class={"prose dark:prose-invert #{@class}"} {@rest}>
      {case Earmark.as_html(@content) do
        {:ok, html, _} -> raw(html)
        {:error, reason, _} -> "<p>Error rendering markdown: #{reason}</p>"
      end}
    </div>
    """
  end

  attr :class, :string, default: "", doc: "CSS classes to apply to the refresh button"
  attr :refreshing, :boolean, default: false, doc: "Whether the refresh is in progress"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the refresh button"

  @spec refresh_button(assigns :: Socket.assigns()) :: Rendered.t()
  def refresh_button(assigns) do
    ~H"""
    <button
      type="button"
      disabled={@refreshing}
      phx-click="refresh"
      class={"inline-flex items-center justify-center p-2 rounded-md text-base-light-600 dark:text-base-dark-400 hover:text-base-light-900 dark:hover:text-base-dark-100 hover:bg-base-light-200 dark:hover:bg-base-dark-700 focus:outline-none focus:ring-2 focus:ring-primary-light dark:focus:ring-primary-dark transition-colors disabled:opacity-50 disabled:cursor-not-allowed #{@class}"}
      aria-label="Refresh"
      {@rest}
    >
      <!-- Refresh icon -->
      <svg
        id="refresh-icon"
        class={"w-5 h-5 #{if @refreshing, do: "animate-spin", else: ""}"}
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="2"
          d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
        />
      </svg>
    </button>
    """
  end

  attr :id, :string, required: true, doc: "The unique ID for the theme toggle button"
  attr :theme, :atom, required: true, doc: "Current theme (:dark or :light)"
  attr :class, :string, default: "", doc: "CSS classes to apply to the theme toggle button"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the theme toggle button"

  @spec theme_toggle(assigns :: Socket.assigns()) :: Rendered.t()
  def theme_toggle(assigns) do
    ~H"""
    <button
      type="button"
      id={@id}
      phx-hook="ThemeToggle"
      class={"inline-flex items-center justify-center p-2 rounded-md text-base-light-600 dark:text-base-dark-400 hover:text-base-light-900 dark:hover:text-base-dark-100 hover:bg-base-light-200 dark:hover:bg-base-dark-700 focus:outline-none focus:ring-2 focus:ring-primary-light dark:focus:ring-primary-dark transition-colors #{@class}"}
      aria-label="Toggle theme"
      {@rest}
    >
      <!-- Sun icon - click to go to light mode -->
      <svg :if={@theme == :dark} class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="2"
          d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z"
        />
      </svg>
      <!-- Moon icon - click to go to dark mode -->
      <svg
        :if={@theme == :light}
        class="w-5 h-5"
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="2"
          d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z"
        />
      </svg>
    </button>
    """
  end
end
