defmodule Clarity.Content.DependencyUpdate do
  @moduledoc """
  Shared LiveComponent rendering a dev-only "update this dependency" button.

  Embedded by the Version Status and Advisories content. The embedder decides
  *whether* to show it (dev + an installable target) and supplies the `app`, the
  `requirement` to widen `mix.exs` to (or `nil`), and the button `label`. On
  click it runs `Clarity.Dependency.Updater` and reboots the node so the new
  version loads; the LiveView reconnects automatically.

  The button is disabled from the moment it's clicked, through the update, and
  through the reboot — it only becomes clickable again if the update fails (so a
  retry is possible) or after the LiveView reconnects fresh post-restart.
  """

  use Clarity.Web, :live_component

  alias Clarity.Dependency.Updater

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(app: assigns.app, requirement: assigns.requirement, label: assigns.label)
     |> assign_new(:phase, fn -> :idle end)
     |> assign_new(:error, fn -> nil end)}
  end

  @impl Phoenix.LiveComponent
  def handle_event("update", _params, socket) do
    %{app: app, requirement: requirement} = socket.assigns

    {:noreply,
     socket
     |> assign(phase: :updating, error: nil)
     |> start_async(:update, fn -> Updater.update(app, requirement) end)}
  end

  @impl Phoenix.LiveComponent
  def handle_async(:update, {:ok, :ok}, socket) do
    # The new code can't be hot-loaded into the running BEAM, so reboot the node;
    # the LiveView reconnects automatically. Delay briefly so this message lands.
    # Stay in :restarting so the button remains disabled until the node is gone.
    Task.start(fn ->
      Process.sleep(500)
      System.restart()
    end)

    {:noreply, assign(socket, phase: :restarting)}
  end

  def handle_async(:update, {:ok, {:error, reason}}, socket) do
    {:noreply, assign(socket, phase: :idle, error: inspect(reason))}
  end

  def handle_async(:update, {:exit, reason}, socket) do
    {:noreply, assign(socket, phase: :idle, error: inspect(reason))}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div>
      <button
        type="button"
        phx-click="update"
        phx-target={@myself}
        disabled={@phase != :idle}
        class="px-3 py-2 rounded-md bg-primary-light dark:bg-primary-dark text-white hover:bg-primary-light/90 dark:hover:bg-primary-dark/90 disabled:opacity-50 transition-colors cursor-pointer disabled:cursor-not-allowed"
      >
        <%= case @phase do %>
          <% :updating -> %>
            Updating…
          <% :restarting -> %>
            Restarting…
          <% :idle -> %>
            {@label}
        <% end %>
      </button>

      <p :if={@phase == :restarting} class="mt-2 text-green-700 dark:text-green-400">
        Updated {@app}. Restarting the server to load it…
      </p>
      <p
        :if={@error}
        class="mt-2 font-semibold text-base-light-900 dark:text-base-dark-100"
      >
        Update failed: {@error}
      </p>
    </div>
    """
  end
end
