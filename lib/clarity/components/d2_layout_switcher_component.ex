defmodule Clarity.D2LayoutSwitcherComponent do
  @moduledoc false

  use Clarity.Web, :live_component

  @layouts [
    %{
      id: "dagre",
      name: "Dagre",
      description: "Default. Hierarchical with reasonable defaults; fast and predictable."
    },
    %{
      id: "elk",
      name: "ELK",
      description: "Eclipse Layout Kernel; clearer routing for dense graphs and nested groups."
    }
  ]

  @impl Phoenix.LiveComponent
  def mount(socket) do
    {:ok, assign(socket, show_dropdown: false, available_layouts: @layouts)}
  end

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl Phoenix.LiveComponent
  def handle_event("toggle_dropdown", _params, socket) do
    {:noreply, assign(socket, show_dropdown: not socket.assigns.show_dropdown)}
  end

  @impl Phoenix.LiveComponent
  def handle_event("close_dropdown", _params, socket) do
    {:noreply, assign(socket, show_dropdown: false)}
  end

  @doc false
  @spec layouts() :: [%{id: String.t(), name: String.t(), description: String.t()}]
  def layouts, do: @layouts

  @doc false
  @spec lookup(String.t()) :: %{id: String.t(), name: String.t(), description: String.t()}
  def lookup(id), do: Enum.find(@layouts, hd(@layouts), &(&1.id == id))
end
