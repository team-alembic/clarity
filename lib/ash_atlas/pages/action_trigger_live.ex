defmodule AshAtlas.ActionTriggerLive do
  @moduledoc false
  use AshAtlas.Web, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
   {:ok, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    TODO: Implement Live View
    """
  end
end
