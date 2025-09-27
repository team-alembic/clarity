defmodule Clarity.EditorButtonComponent do
  @moduledoc false

  use Phoenix.LiveComponent

  attr :anno, :any, required: true, doc: "The annotation to extract file path from"

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <button
      phx-click={if @editor_available, do: "open_in_editor", else: nil}
      phx-target={if @editor_available, do: @myself, else: nil}
      disabled={not @editor_available}
      class={[
        "p-2 rounded transition-colors",
        if @editor_available do
          "hover:bg-base-light-200 dark:hover:bg-base-dark-800 text-base-light-600 dark:text-base-dark-400 hover:text-primary-light dark:hover:text-primary-dark"
        else
          "opacity-50 cursor-not-allowed text-base-light-400 dark:text-base-dark-600"
        end
      ]}
      title={
        if @editor_available, do: "Open in Editor", else: "Set EDITOR environment variable to enable"
      }
    >
      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="2"
          d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"
        />
      </svg>
    </button>
    """
  end

  @impl Phoenix.LiveComponent
  def mount(socket), do: {:ok, assign(socket, editor_available: editor_available?())}

  @impl Phoenix.LiveComponent
  def handle_event("open_in_editor", _params, socket) do
    result =
      with {:ok, file_path} <- get_file_path_from_anno(socket.assigns.anno),
           :ok <- open_in_editor(file_path) do
        {:success, "Opened #{Path.basename(file_path)} in editor"}
      else
        {:error, :no_file} -> {:error, "Could not determine source file path"}
        {:error, :no_editor} -> {:error, "EDITOR environment variable not set"}
        {:error, reason} -> {:error, "Failed to open editor: #{inspect(reason)}"}
      end

    case result do
      {:success, message} ->
        send(self(), {:flash, :success, message})

      {:error, message} ->
        send(self(), {:flash, :error, message})
    end

    {:noreply, socket}
  end

  @spec get_file_path_from_anno(:erl_anno.anno()) :: {:ok, String.t()} | {:error, :no_file}
  defp get_file_path_from_anno(anno) do
    case :erl_anno.file(anno) do
      :undefined -> {:error, :no_file}
      file -> {:ok, List.to_string(file)}
    end
  end

  @spec open_in_editor(String.t()) :: :ok | {:error, term()}
  defp open_in_editor(file_path) do
    case System.get_env("EDITOR") do
      nil ->
        {:error, :no_editor}

      editor ->
        case System.cmd(editor, [file_path], stderr_to_stdout: true) do
          {_output, 0} -> :ok
          {error, _code} -> {:error, error}
        end
    end
  rescue
    error -> {:error, error}
  end

  @spec editor_available?() :: boolean()
  defp editor_available? do
    case System.fetch_env("EDITOR") do
      {:ok, editor} ->
        cond do
          editor == "" -> false
          File.exists?(editor) -> true
          System.find_executable(editor) != nil -> true
          true -> false
        end

      :error ->
        false
    end
  end
end
