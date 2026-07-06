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

  @impl Phoenix.LiveComponent
  def handle_event("switch_lens", %{"lens-id" => lens_id}, socket) do
    path = Path.join([socket.assigns.prefix, lens_id])

    {:noreply,
     socket
     |> assign(show_dropdown: false)
     |> push_navigate(to: path)}
  end
end
