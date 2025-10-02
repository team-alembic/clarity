defmodule Clarity.LensSwitcherComponent do
  @moduledoc false

  use Clarity.Web, :live_component

  alias Clarity.Perspective.Registry

  @impl Phoenix.LiveComponent
  def mount(socket) do
    {:ok, assign(socket, show_dropdown: false)}
  end

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    available_lenses = Registry.get_all_lenses()

    {:ok,
     socket
     |> assign(assigns)
     |> assign(available_lenses: available_lenses)}
  end

  @impl Phoenix.LiveComponent
  def handle_event("toggle_dropdown", _params, socket) do
    {:noreply, assign(socket, show_dropdown: not socket.assigns.show_dropdown)}
  end

  @impl Phoenix.LiveComponent
  def handle_event("close_dropdown", _params, socket) do
    {:noreply, assign(socket, show_dropdown: false)}
  end

  @impl Phoenix.LiveComponent
  def handle_event("switch_lens", %{"lens-id" => lens_id}, socket) do
    path = Path.join([socket.assigns.prefix, lens_id])

    {:noreply,
     socket
     |> assign(show_dropdown: false)
     |> push_patch(to: path)}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div class="relative">
      <!-- Aperture icon button -->
      <button
        phx-click={unless @show_dropdown, do: "toggle_dropdown"}
        phx-target={@myself}
        class="flex items-center space-x-2 px-3 py-2 rounded-md text-base-light-600 dark:text-base-dark-400 hover:text-base-light-900 dark:hover:text-base-dark-100 hover:bg-base-light-200 dark:hover:bg-base-dark-700 transition-colors"
        aria-label="Switch lens perspective"
      >
        <!-- Camera aperture SVG icon - Attribution: https://www.svgrepo.com/svg/349150/aperture / Open Iconic -->
        <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 8 8" xmlns="http://www.w3.org/2000/svg">
          <path d="M4 0c-.69 0-1.34.19-1.91.5l3.22 2.34.75-2.25c-.6-.36-1.31-.59-2.06-.59zm-2.75 1.13c-.76.73-1.25 1.74-1.25 2.88 0 .25.02.48.06.72l3.09-2.22-1.91-1.38zm5.63.13l-1.22 3.75h2.19c.08-.32.16-.65.16-1 0-1.07-.44-2.03-1.13-2.75zm-4.72 3.22l-1.75 1.25c.55 1.13 1.6 1.99 2.88 2.22l-1.13-3.47zm1.56 1.53l.63 1.97c1.33-.12 2.46-.88 3.09-1.97h-3.72z" />
        </svg>
        <span class="text-lg">{@lens.icon.()}</span>
        <svg
          class="w-4 h-4 transition-transform"
          class={if @show_dropdown, do: "rotate-180", else: ""}
          fill="currentColor"
          viewBox="0 0 20 20"
        >
          <path
            fill-rule="evenodd"
            d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z"
            clip-rule="evenodd"
          />
        </svg>
      </button>
      
    <!-- Dropdown menu -->
      <div
        :if={@show_dropdown}
        class="absolute top-full right-0 mt-1 bg-white dark:bg-base-dark-800 rounded-md shadow-lg border border-base-light-300 dark:border-base-dark-600 z-50 w-80"
        phx-click-away="close_dropdown"
        phx-target={@myself}
      >
        <div class="py-1">
          <%= for lens <- @available_lenses do %>
            <button
              phx-click="switch_lens"
              phx-value-lens-id={lens.id}
              phx-target={@myself}
              class={[
                "w-full text-left flex items-center space-x-3 px-4 py-2 hover:bg-base-light-100 dark:hover:bg-base-dark-700 transition-colors",
                if(lens.id == @lens.id, do: "bg-primary-light/10 dark:bg-primary-dark/10")
              ]}
            >
              <span class="text-lg">{lens.icon.()}</span>
              <div class="flex-1">
                <div class="text-sm font-medium text-base-light-900 dark:text-base-dark-100">
                  {lens.name}
                </div>
                <%= if lens.description do %>
                  <div class="text-xs text-base-light-600 dark:text-base-dark-400">
                    {lens.description}
                  </div>
                <% end %>
              </div>
              <%= if lens.id == @lens.id do %>
                <svg
                  class="w-4 h-4 text-primary-light dark:text-primary-dark shrink-0"
                  fill="currentColor"
                  viewBox="0 0 20 20"
                >
                  <path
                    fill-rule="evenodd"
                    d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
                    clip-rule="evenodd"
                  />
                </svg>
              <% end %>
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
