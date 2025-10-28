defmodule Clarity.EditorButtonComponent do
  @moduledoc false

  use Phoenix.LiveComponent

  import Clarity.IconComponents

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
end
