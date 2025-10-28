defmodule Clarity.EditorButtonComponent do
  @moduledoc false

  use Phoenix.LiveComponent

  alias Clarity.OpenEditor
  alias Clarity.SourceLocation

  @impl Phoenix.LiveComponent
  def update(%{source_location: source_location}, socket) do
    editor_action = OpenEditor.action(source_location)

    {:ok,
     assign(socket,
       source_location: source_location,
       editor_action: editor_action
     )}
  end

  @impl Phoenix.LiveComponent
  def handle_event(
        "open_in_editor",
        _params,
        %{assigns: %{editor_action: {:execute, execute_fn}, source_location: source_location}} =
          socket
      ) do
    case execute_fn.() do
      :ok ->
        filename = SourceLocation.file_path(source_location, :cwd) || "unknown file"
        send(self(), {:flash, :success, "Opened #{filename} in editor"})

      {:error, reason} ->
        send(self(), {:flash, :error, "Failed to execute editor: #{inspect(reason)}"})
    end

    {:noreply, socket}
  end

  @spec render_icon(map()) :: Phoenix.LiveView.Rendered.t()
  defp render_icon(assigns) do
    ~H"""
    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"
      />
    </svg>
    """
  end
end
