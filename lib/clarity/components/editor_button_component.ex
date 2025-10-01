defmodule Clarity.EditorButtonComponent do
  @moduledoc false

  use Phoenix.LiveComponent

  alias Clarity.OpenEditor
  alias Clarity.SourceLocation

  attr :source_location, SourceLocation, required: true, doc: "The source location for the file"

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div>
      <%= case @editor_action do %>
        <% :action_not_available -> %>
        <% :editor_not_available -> %>
          <button
            disabled
            class="p-2 rounded-xs transition-colors opacity-50 cursor-not-allowed text-base-light-400 dark:text-base-dark-600"
            title="No editor configured - set CLARITY_EDITOR, ELIXIR_EDITOR, or EDITOR environment variable"
          >
            <.render_icon />
          </button>
        <% {:url, url} -> %>
          <a
            href={url}
            target="_blank"
            class="p-2 rounded-xs transition-colors hover:bg-base-light-200 dark:hover:bg-base-dark-800 text-base-light-600 dark:text-base-dark-400 hover:text-primary-light dark:hover:text-primary-dark block"
            title="Open in Browser"
          >
            <.render_icon />
          </a>
        <% {:execute, _execute_fn} -> %>
          <button
            phx-click="open_in_editor"
            phx-target={@myself}
            class="p-2 rounded-xs transition-colors hover:bg-base-light-200 dark:hover:bg-base-dark-800 text-base-light-600 dark:text-base-dark-400 hover:text-primary-light dark:hover:text-primary-dark"
            title="Open in Editor"
          >
            <.render_icon />
          </button>
      <% end %>
    </div>
    """
  end

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
