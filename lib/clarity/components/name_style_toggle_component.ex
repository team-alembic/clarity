defmodule Clarity.NameStyleToggleComponent do
  @moduledoc """
  Header toggle that flips between fully-qualified module names
  (`Demo.Accounts.Organization`) and short module names
  (`Organization`) in the sidebar tree, breadcrumbs, and other vertex
  labels.
  """

  use Clarity.Web, :live_component

  @impl Phoenix.LiveComponent
  def mount(socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end
end
