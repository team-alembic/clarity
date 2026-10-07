defmodule DemoWeb.InboxLive do
  @moduledoc "LiveView stub for the helpdesk inbox. Diagram demo only."

  use Phoenix.LiveView

  @impl Phoenix.LiveView
  def mount(_params, _session, socket), do: {:ok, socket}

  @impl Phoenix.LiveView
  def render(assigns), do: ~H"<div>Inbox</div>"
end
