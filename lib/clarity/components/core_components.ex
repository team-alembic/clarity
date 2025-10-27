defmodule Clarity.CoreComponents do
  @moduledoc false

  use Phoenix.Component

  import Clarity.Components.MarkdownComponent
  import Phoenix.HTML

  alias Clarity.Content
  alias Clarity.Perspective.Lens
  alias Clarity.Vertex
  alias Phoenix.LiveView.JS
  alias Phoenix.LiveView.Rendered
  alias Phoenix.LiveView.Socket

  attr :socket, Socket, required: true, doc: "The LiveView socket"
  attr :prefix, :string, default: "/", doc: "The URL prefix for links"

  attr :lens, Lens,
    required: true,
    doc: "Current lens for perspective switching"

  attr :theme, :atom, required: true, doc: "Current theme (:dark or :light)"
  attr :clarity_pid, :any, required: true, doc: "PID of the Clarity server process"
  attr :class, :string, default: "", doc: "CSS classes to apply to the header container"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the header container"

  @spec header(assigns :: Socket.assigns()) :: Rendered.t()
  def header(assigns) do
    ~H"""
    <header
      class={"flex items-center px-6 py-4 bg-base-light-100 dark:bg-base-dark-800 shadow-md #{@class}"}
      {@rest}
    >
      <.link patch={@prefix} class="mr-4">
        <img
          src={Clarity.Resources.logo_uri()}
          alt="Ash Logo"
          class="h-8 w-8"
        />
      </.link>
      <h1 class="text-2xl font-bold tracking-tight flex-1 truncate text-base-light-900 dark:text-base-dark-50">
        <.link patch={@prefix} class="mr-4">
          Clarity
        </.link>
      </h1>

      <div class="flex justify-center mx-4">
        {live_render(@socket, Clarity.Components.StatusLive,
          id: "clarity-status",
          session: %{"clarity_pid" => @clarity_pid}
        )}
      </div>

      <div class="flex items-center space-x-2">
        <.live_component
          module={Clarity.LensSwitcherComponent}
          id="lens-switcher"
          prefix={@prefix}
          lens={@lens}
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
      class={"inline-flex items-center justify-center p-2 rounded-md text-base-light-600 dark:text-base-dark-400 hover:text-base-light-900 dark:hover:text-base-dark-100 hover:bg-base-light-200 dark:hover:bg-base-dark-700 focus:outline-hidden focus:ring-2 focus:ring-primary-light dark:focus:ring-primary-dark transition-colors #{@class}"}
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
                "w-5 h-5 mr-3 shrink-0",
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
              "ml-4 shrink-0 rounded-md p-1 transition-colors",
              case kind do
                "info" -> "hover:bg-blue-600/20 dark:hover:bg-blue-400/20"
                "success" -> "hover:bg-green-600/20 dark:hover:bg-green-400/20"
                "error" -> "hover:bg-red-600/20 dark:hover:bg-red-400/20"
                "warning" -> "hover:bg-yellow-600/20 dark:hover:bg-yellow-400/20"
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

  attr :class, :string, default: "", doc: "CSS classes to apply to the loading spinner container"

  attr :rest, :global,
    doc: "the arbitrary HTML attributes to add to the loading spinner container"

  @spec loading_spinner(assigns :: Socket.assigns()) :: Rendered.t()
  def loading_spinner(assigns) do
    ~H"""
    <div class={"flex items-center justify-center py-8 #{@class}"} {@rest}>
      <svg
        class="animate-spin h-8 w-8 text-primary-light dark:text-primary-dark"
        xmlns="http://www.w3.org/2000/svg"
        fill="none"
        viewBox="0 0 24 24"
      >
        <circle
          class="opacity-25"
          cx="12"
          cy="12"
          r="10"
          stroke="currentColor"
          stroke-width="4"
        >
        </circle>
        <path
          class="opacity-75"
          fill="currentColor"
          d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
        >
        </path>
      </svg>
    </div>
    """
  end

  @doc """
  Renders the Clarity splash screen with animated logo.
  """
  attr :class, :string, default: nil
  attr :rest, :global

  @spec splash_screen(map()) :: Rendered.t()
  def splash_screen(assigns) do
    ~H"""
    <div
      id="splash"
      class={"min-h-screen w-full flex flex-col items-center justify-center bg-base-light-50 dark:bg-base-dark-900 #{@class}"}
      {@rest}
    >
      {raw(Clarity.Resources.splash())}

      <.loading_spinner class="mt-8" />
    </div>
    """
  end

  @doc """
  Renders tab navigation for switching between content views.
  """
  attr :contents, :list, required: true, doc: "List of available content tabs"
  attr :content, Content, doc: "Currently selected content tab"
  attr :prefix, :string, required: true, doc: "URL prefix for links"
  attr :lens, Lens, required: true, doc: "Current lens for navigation"

  attr :vertex, :any,
    required: true,
    doc: "Current vertex being viewed (implements Clarity.Vertex protocol)"

  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the tabs container"

  @spec tabs(assigns :: Socket.assigns()) :: Rendered.t()
  def tabs(assigns) do
    ~H"""
    <nav
      class="tabs border-b border-base-light-300 dark:border-base-dark-700 bg-base-light-100 dark:bg-base-dark-900 px-4 flex justify-between items-center"
      {@rest}
    >
      <ul class="flex space-x-2">
        <li :for={content <- @contents}>
          <.link
            patch={Path.join([@prefix, @lens.id, Clarity.Vertex.id(@vertex), content.id])}
            class={
            "inline-block px-4 py-2 rounded-t-md font-medium transition-colors " <>
            if @content && content.id == @content.id,
              do: "bg-base-light-200 dark:bg-base-dark-800 text-primary-light dark:text-primary-dark border-b-2 border-primary-light dark:border-primary-dark",
              else: "text-base-light-600 dark:text-base-dark-400 hover:text-primary-light dark:hover:text-primary-dark hover:bg-base-light-200 dark:hover:bg-base-dark-800"
            }
            title={content.description}
          >
            {content.name}
          </.link>
        </li>
      </ul>

      <div class="flex items-center">
        <%= if Vertex.SourceLocationProvider.source_location(@vertex) != nil do %>
          <.live_component
            module={Clarity.EditorButtonComponent}
            id="editor-button"
            source_location={Vertex.SourceLocationProvider.source_location(@vertex)}
          />
        <% end %>
      </div>
    </nav>
    """
  end

  @doc """
  Renders an error page when a lens cannot be found.
  """
  attr :prefix, :string, required: true, doc: "URL prefix for navigation link"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the error container"

  @spec lens_not_found_error(assigns :: Socket.assigns()) :: Rendered.t()
  def lens_not_found_error(assigns) do
    ~H"""
    <div
      class="bg-base-light-50 dark:bg-base-dark-900 text-base-light-900 dark:text-base-dark-100 min-h-screen w-full flex items-center justify-center p-8"
      {@rest}
    >
      <div class="max-w-lg w-full text-center">
        <h1 class="text-4xl font-bold text-base-light-900 dark:text-base-dark-100 mb-6">
          Lens Not Found
        </h1>
        <p class="text-lg text-base-light-600 dark:text-base-dark-400 mb-8">
          The requested lens could not be found. It may not be available or the URL is incorrect.
        </p>
        <.link
          patch={@prefix}
          class="inline-flex items-center px-6 py-3 border border-transparent text-base font-medium rounded-xs shadow-xs text-white bg-primary-light hover:bg-primary-light/90 dark:bg-primary-dark dark:hover:bg-primary-dark/90 focus:outline-hidden focus:ring-2 focus:ring-offset-2 focus:ring-primary-light dark:focus:ring-primary-dark"
        >
          ← Go to Default Page
        </.link>
      </div>
    </div>
    """
  end

  @doc """
  Renders an error message when a vertex cannot be found.
  """
  attr :prefix, :string, required: true, doc: "URL prefix for navigation link"
  attr :lens, Lens, required: true, doc: "Current lens for navigation"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the error container"

  @spec vertex_not_found_error(assigns :: Socket.assigns()) :: Rendered.t()
  def vertex_not_found_error(assigns) do
    ~H"""
    <div class="content p-8 text-center" {@rest}>
      <div class="max-w-md mx-auto">
        <h1 class="text-3xl font-bold text-base-light-900 dark:text-base-dark-100 mb-4">
          Vertex Not Found
        </h1>
        <p class="text-base-light-600 dark:text-base-dark-400 mb-6">
          The requested vertex could not be found. It may have been removed or the URL is incorrect.
        </p>
        <.link
          patch={Path.join([@prefix, @lens.id, "root"])}
          class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-xs shadow-xs text-white bg-primary-light hover:bg-primary-light/90 dark:bg-primary-dark dark:hover:bg-primary-dark/90 focus:outline-hidden focus:ring-2 focus:ring-offset-2 focus:ring-primary-light dark:focus:ring-primary-dark"
        >
          ← Go to Root
        </.link>
      </div>
    </div>
    """
  end

  @doc """
  Renders an error message when content cannot be found for a vertex.
  """
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the error container"

  @spec content_not_found_error(assigns :: Socket.assigns()) :: Rendered.t()
  def content_not_found_error(assigns) do
    ~H"""
    <div class="content p-8 text-center" {@rest}>
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

  @doc """
  Renders the content view based on the content type (live component, live view, or static).
  """
  attr :content, Content, doc: "The content to render"
  attr :vertex, :any, required: true, doc: "Current vertex being viewed"
  attr :lens, Lens, required: true, doc: "Current lens for rendering"
  attr :socket, Socket, required: true, doc: "The LiveView socket"
  attr :theme, :atom, required: true, doc: "Current theme (:dark or :light)"
  attr :zoom_graph, :any, required: true, doc: "The zoomed subgraph for visualization"
  attr :zoom_level, :any, required: true, doc: "Zoom level tuple {outgoing, incoming}"
  attr :prefix, :string, required: true, doc: "URL prefix for links"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the content container"

  @spec render_content(assigns :: Socket.assigns()) :: Rendered.t()
  def render_content(assigns) do
    ~H"""
    <% content_props = %{
      theme: @theme,
      zoom_subgraph: @zoom_graph,
      zoom_level: @zoom_level
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
          {content_props}
        />
      <% @content.live_view? -> %>
        {live_render(@socket, @content.provider,
          id: "content-view",
          session: %{
            "vertex" => @vertex,
            "lens" => @lens
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
    """
  end
end
