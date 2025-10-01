defmodule Clarity.CoreComponents do
  @moduledoc false

  use Phoenix.Component

  alias Clarity.Perspective.Lens
  alias Clarity.Vertex
  alias Phoenix.LiveView.JS
  alias Phoenix.LiveView.Rendered
  alias Phoenix.LiveView.Socket

  attr :prefix, :string, default: "/", doc: "The URL prefix for links"

  attr :lens, Lens,
    required: true,
    doc: "Current lens for perspective switching"

  attr :theme, :atom, required: true, doc: "Current theme (:dark or :light)"
  attr :refreshing, :boolean, default: false, doc: "Whether a refresh is in progress"
  attr :work_status, :atom, required: true, doc: "Current work status (:working or :done)"

  attr :queue_info, :map,
    required: true,
    doc: "Queue information with future_queue, in_progress, total_vertices"

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
          src={Clarity.Resources.logo_uri()}
          alt="Ash Logo"
          class="h-8 w-8"
        />
      </.link>
      <h1 class="text-2xl font-bold tracking-tight flex-1 truncate text-base-light-900 dark:text-base-dark-50">
        <.link patch={Path.join([@prefix, "root", "graph"])} class="mr-4">
          Clarity
        </.link>
      </h1>

      <div class="flex justify-center mx-4">
        <.progress_bar work_status={@work_status} queue_info={@queue_info} />
      </div>

      <div class="flex items-center space-x-2">
        <.refresh_button refreshing={@refreshing} />
        <.live_component
          module={Clarity.LensSwitcherComponent}
          id="lens-switcher"
          prefix={@prefix}
          current_lens={@lens}
        />
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

  attr :tree, :any, required: true, doc: "The navigation tree digraph"
  attr :prefix, :string, default: "/", doc: "The URL prefix for links"
  attr :current, :any, required: true, doc: "The currently selected node in the tree"

  attr :lens, Lens,
    required: true,
    doc: "Current lens for perspective switching"

  attr :breadcrumbs, :list, required: true, doc: "List of breadcrumb vertices"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the navigation container"

  @spec navigation(assigns :: Socket.assigns()) :: Rendered.t()
  def navigation(assigns) do
    ~H"""
    <nav {@rest}>
      <.navigation_tree
        tree={@tree}
        prefix={@prefix}
        current={@current}
        lens={@lens}
        breadcrumbs={@breadcrumbs}
      />
    </nav>
    """
  end

  attr :tree, :any, required: true, doc: "The navigation tree digraph"
  attr :prefix, :string, default: "/", doc: "The URL prefix for links"
  attr :current, :any, required: true, doc: "The currently selected node in the tree"

  attr :lens, Lens,
    required: true,
    doc: "Current lens for perspective switching"

  attr :breadcrumbs, :list, required: true, doc: "List of breadcrumb vertices"

  @spec navigation_tree(assigns :: Socket.assigns()) :: Rendered.t()
  defp navigation_tree(assigns) do
    ~H"""
    <div :for={{label, vertices} <- @tree.out_edges} :if={label != :content}>
      <span class="cursor-pointer select-none text-base-light-600 dark:text-base-dark-400 hover:text-primary-light dark:hover:text-primary-dark px-2 py-1 rounded-sm group-open:bg-base-light-200 dark:group-open:bg-base-dark-700 transition-colors">
        {label}
      </span>
      <ul class="border-l border-base-light-300 dark:border-base-dark-700 pl-2 space-y-1">
        <li :for={vertex <- vertices}>
          <.navigation_node
            tree={vertex}
            prefix={@prefix}
            current={@current}
            lens={@lens}
            breadcrumbs={@breadcrumbs}
          />
        </li>
      </ul>
    </div>
    """
  end

  attr :tree, :any, required: true, doc: "The navigation tree digraph"
  attr :prefix, :string, default: "/", doc: "The URL prefix for links"

  attr :lens, Lens,
    required: true,
    doc: "Current lens for perspective switching"

  attr :current, :any, required: true, doc: "The currently selected node in the tree"
  attr :breadcrumbs, :list, required: true, doc: "List of breadcrumb vertices"

  @spec navigation_node(assigns :: Socket.assigns()) :: Rendered.t()
  defp navigation_node(assigns) do
    ~H"""
    <%= if Enum.any?(@tree.out_edges, &(elem(&1, 0) != :content)) do %>
      <details open={Enum.any?(@breadcrumbs, &(&1 == @tree.vertex))}>
        <summary>
          <.link
            patch={Path.join([@prefix, @lens.id, Clarity.Vertex.unique_id(@tree.vertex)])}
            class={
              "inline px-2 py-1 rounded-sm hover:bg-base-light-200 dark:hover:bg-base-dark-700 hover:text-primary-light dark:hover:text-primary-dark transition-colors font-medium" <>
              if @tree.vertex == @current, do: " bg-primary-light dark:bg-primary-dark text-white dark:text-base-dark-900", else: ""
            }
          >
            <.vertex_name vertex={@tree.vertex} />
          </.link>
        </summary>
        <div class="ml-4 group">
          <.navigation_tree
            tree={@tree}
            prefix={@prefix}
            current={@current}
            lens={@lens}
            breadcrumbs={@breadcrumbs}
          />
        </div>
      </details>
    <% else %>
      <.link
        patch={Path.join([@prefix, @lens.id, Clarity.Vertex.unique_id(@tree.vertex)])}
        class={
              "inline px-2 py-1 rounded-sm hover:bg-base-light-200 dark:hover:bg-base-dark-700 hover:text-primary-light dark:hover:text-primary-dark transition-colors font-medium" <>
              if @tree.vertex == @current, do: " bg-primary-light dark:bg-primary-dark text-white dark:text-base-dark-900", else: ""
            }
      >
        <.vertex_name vertex={@tree.vertex} />
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

  attr :work_status, :atom, required: true, doc: "Current work status (:working or :done)"

  attr :queue_info, :map,
    required: true,
    doc: "Queue information with future_queue, in_progress, total_vertices"

  attr :class, :string, default: "", doc: "CSS classes to apply to the progress bar container"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the progress bar container"

  @spec progress_bar(assigns :: Socket.assigns()) :: Rendered.t()
  def progress_bar(assigns) do
    ~H"""
    <div
      :if={@work_status == :working}
      class={"flex items-center space-x-3 px-4 py-2 bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-md #{@class}"}
      {@rest}
    >
      <!-- Spinner -->
      <svg
        class="animate-spin h-4 w-4 text-blue-600 dark:text-blue-400"
        fill="none"
        viewBox="0 0 24 24"
      >
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4">
        </circle>
        <path
          class="opacity-75"
          fill="currentColor"
          d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
        >
        </path>
      </svg>
      
    <!-- Progress text -->
      <span class="text-sm text-blue-700 dark:text-blue-300 font-medium">
        Processing...
      </span>
      
    <!-- Queue info -->
      <span class="text-xs text-blue-600 dark:text-blue-400">
        <%= if @queue_info.in_progress > 0 or @queue_info.future_queue > 0 do %>
          {@queue_info.in_progress} active, {@queue_info.future_queue + @queue_info.requeue_queue} queued
        <% else %>
          {@queue_info.total_vertices} items total
        <% end %>
      </span>
      
    <!-- Progress bar -->
      <%= if @queue_info.total_vertices > 0 do %>
        <div class="flex-1 bg-blue-200 dark:bg-blue-700 rounded-full h-2 max-w-32">
          <div
            class="bg-blue-600 dark:bg-blue-400 h-2 rounded-full transition-all duration-300"
            style={"width: #{progress_percentage(@queue_info)}%"}
          >
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  attr :flash, :map, default: %{}, doc: "The flash messages to display"
  attr :class, :string, default: "", doc: "CSS classes to apply to the flash container"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  @spec flash_group(assigns :: Socket.assigns()) :: Rendered.t()
  def flash_group(assigns) do
    ~H"""
    <div
      :if={@flash != %{}}
      class={"fixed top-0 left-0 right-0 z-50 #{@class}"}
      {@rest}
    >
      <div class="mx-auto max-w-3xl px-4 py-4">
        <div
          :for={{kind, message} <- @flash}
          :if={message}
          id={"flash-#{kind}"}
          phx-hook="Flash"
          class={[
            "mb-2 rounded-md p-4 shadow-lg border flex items-center justify-between transition-all duration-300",
            case kind do
              "info" ->
                "bg-blue-50 dark:bg-blue-900 text-blue-800 dark:text-blue-100 border-blue-200 dark:border-blue-700"

              "success" ->
                "bg-green-50 dark:bg-green-900 text-green-800 dark:text-green-100 border-green-200 dark:border-green-700"

              "error" ->
                "bg-red-100 dark:bg-red-900 text-red-900 dark:text-red-100 border-red-300 dark:border-red-600"

              "warning" ->
                "bg-yellow-50 dark:bg-yellow-900 text-yellow-800 dark:text-yellow-100 border-yellow-200 dark:border-yellow-700"

              _ ->
                "bg-gray-50 dark:bg-gray-900 text-gray-800 dark:text-gray-100 border-gray-200 dark:border-gray-700"
            end
          ]}
        >
          <div class="flex items-center">
            <!-- Icon -->
            <svg
              class={[
                "w-5 h-5 mr-3 flex-shrink-0",
                case kind do
                  "info" -> "text-blue-500 dark:text-blue-400"
                  "success" -> "text-green-500 dark:text-green-400"
                  "error" -> "text-red-600 dark:text-red-300"
                  "warning" -> "text-yellow-500 dark:text-yellow-400"
                  _ -> "text-gray-500 dark:text-gray-400"
                end
              ]}
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <%= case kind do %>
                <% "info" -> %>
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                <% "success" -> %>
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                <% "error" -> %>
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                <% "warning" -> %>
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.732-.833-2.464 0L4.732 18.5c-.77.833.192 2.5 1.732 2.5z"
                  />
                <% _ -> %>
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
              <% end %>
            </svg>
            
    <!-- Message -->
            <span class="flex-1 font-medium">{message}</span>
          </div>
          
    <!-- Close button -->
          <button
            type="button"
            phx-click={JS.hide(to: "#flash-#{kind}")}
            class={[
              "ml-4 flex-shrink-0 rounded-md p-1 hover:bg-opacity-20 transition-colors",
              case kind do
                "info" -> "hover:bg-blue-600 dark:hover:bg-blue-400"
                "success" -> "hover:bg-green-600 dark:hover:bg-green-400"
                "error" -> "hover:bg-red-600 dark:hover:bg-red-400"
                "warning" -> "hover:bg-yellow-600 dark:hover:bg-yellow-400"
                _ -> "hover:bg-gray-600 dark:hover:bg-gray-400"
              end
            ]}
            aria-label="Close flash message"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M6 18L18 6M6 6l12 12"
              />
            </svg>
          </button>
        </div>
      </div>
    </div>
    """
  end

  # Calculate progress percentage based on completed work
  @spec progress_percentage(queue_info :: map()) :: number()
  defp progress_percentage(%{
         future_queue: future,
         in_progress: in_progress,
         total_vertices: total
       })
       when total > 0 do
    completed = max(0, total - future - in_progress)
    Float.round(completed / total * 100, 1)
  end

  defp progress_percentage(_), do: 0
end
