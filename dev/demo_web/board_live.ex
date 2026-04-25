defmodule DemoWeb.BoardLive do
  @moduledoc "LiveView stub for the project board. Diagram demo only."

  use Phoenix.LiveView

  @impl Phoenix.LiveView
  def mount(_params, _session, socket), do: {:ok, socket}

  @impl Phoenix.LiveView
  def render(assigns), do: ~H"<div>Board</div>"
end
