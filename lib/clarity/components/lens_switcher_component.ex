defmodule Clarity.LensSwitcherComponent do
  @moduledoc false

  use Clarity.Web, :live_component

  alias Clarity.Perspective.Lensmaker

  @impl Phoenix.LiveComponent
  def mount(socket) do
    {:ok, assign(socket, show_dropdown: false)}
  end

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    available_lenses = Lensmaker.get_all_lenses()

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

  # Switching lens stays on the current page's LiveView, so it patches. A page
  # can say where a lens leads with `lens_path` (the reports page keeps the
  # report shown); otherwise it's the lens's root.
  @impl Phoenix.LiveComponent
  def handle_event("switch_lens", %{"lens-id" => lens_id}, socket) do
    path =
      case socket.assigns[:lens_path] do
        nil -> Path.join([socket.assigns.prefix, lens_id])
        lens_path -> lens_path.(lens_id)
      end

    {:noreply,
     socket
     |> assign(show_dropdown: false)
     |> push_patch(to: path)}
  end
end
