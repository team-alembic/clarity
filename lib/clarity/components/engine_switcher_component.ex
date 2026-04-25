defmodule Clarity.EngineSwitcherComponent do
  @moduledoc false

  use Clarity.Web, :live_component

  @engines [
    %{
      id: "dot",
      name: "Hierarchical",
      description: "Default. Layered top-down or left-right; best for trees and DAGs."
    },
    %{
      id: "osage",
      name: "Packed",
      description: "Packs disconnected clusters and components into a tight grid."
    },
    %{
      id: "neato",
      name: "Spring",
      description: "Force-directed layout with springs; good for small undirected graphs."
    },
    %{
      id: "fdp",
      name: "Force",
      description: "Force-directed; similar to neato, supports clusters."
    },
    %{
      id: "sfdp",
      name: "Scalable Force",
      description: "Multiscale force-directed; for large graphs."
    },
    %{
      id: "circo",
      name: "Circular",
      description: "Places nodes on circles; useful for cyclic structures."
    },
    %{
      id: "twopi",
      name: "Radial",
      description: "Radial concentric circles around a chosen root."
    },
    %{
      id: "patchwork",
      name: "Treemap",
      description: "Squarified treemap; cluster sizes proportional to weight."
    }
  ]

  @impl Phoenix.LiveComponent
  def mount(socket) do
    {:ok, assign(socket, show_dropdown: false, available_engines: @engines)}
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
  @spec engines() :: [%{id: String.t(), name: String.t(), description: String.t()}]
  def engines, do: @engines

  @doc false
  @spec lookup(String.t()) :: %{id: String.t(), name: String.t(), description: String.t()}
  def lookup(id), do: Enum.find(@engines, hd(@engines), &(&1.id == id))
end
