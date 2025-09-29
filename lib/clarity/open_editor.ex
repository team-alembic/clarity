defmodule Clarity.OpenEditor do
  @moduledoc """
  Handles opening files in editors or browsers based on configuration.

  This module provides a flexible editor integration system that supports:
  - Local editor commands with template variable substitution
  - URL mode for opening files in browsers via source URLs
  - Case-insensitive template variables (`__FILE__`, `__LINE__`, `__COLUMN__`)
  - Multiple configuration sources with priority hierarchy

  ## Configuration Priority

  The editor configuration is resolved in the following order (highest to lowest priority):

  1. `config :clarity, editor: ...`
  2. `CLARITY_EDITOR` environment variable
  3. `ELIXIR_EDITOR` environment variable
  4. `EDITOR` environment variable

  ## Template Variables

  When using system command mode, the following case-insensitive template variables
  are supported:

  - `__FILE__` - replaced with the file path
  - `__LINE__` - replaced with the line number
  - `__COLUMN__` - replaced with the column number

  ## URL Mode

  To enable URL mode, set the editor configuration to `"__URL__"`
  (case-insensitive) or the atom `:url`. In URL mode, the module will:

  1. Determine which application/dependency the file belongs to
  2. Extract the `source_url` from that application's configuration
  3. Generate a platform-specific URL using ExDoc-style patterns
  4. Return the URL for opening in a browser

  ## Configuration examples

      config :clarity, editor: "code --goto __FILE__:__LINE__:__COLUMN__"
      config :clarity, editor: "subl __FILE__:__LINE__"
      config :clarity, editor: "__URL__"  # Enable URL mode

  > #### Command Execution {: .warning}
  >
  > This module executes system commands based on user configuration.
  > Ensure that the configured commands are safe and trusted to avoid security
  > risks. If you run this in an untrusted environment, set the editor to `:url`
  > or `"__URL__"` to avoid executing arbitrary commands.
  >
  > Clarity does not validate or sanitize the commands; it simply substitutes
  > the template variables and executes them as-is.
  >
  > Variable substitution does not escape special characters, so be cautious
  > if file paths may contain spaces or shell-sensitive characters.

  """

  require Logger

  @type action_result ::
          :editor_not_available
          | :action_not_available
          | {:url, String.t()}
          | {:execute, (-> :ok | {:error, term()})}

  @doc """
  Determines the action available for a given source location.

  Returns the appropriate action based on editor configuration and the ability
  to process the source location. This is the main entry point for editor
  integration.

  ## Returns

  - `:editor_not_available` - No editor is configured
  - `:action_not_available` - Editor is configured but action cannot be determined
    (e.g., URL building failed, command preparation failed)
  - `{:url, url}` - URL mode with successfully built URL
  - `{:execute, function}` - System command mode with executable function

  ## Examples

      case Clarity.OpenEditor.action(source_location) do
        :editor_not_available -> 
          # Don't show editor button
        :action_not_available -> 
          # Don't show editor button 
        {:url, url} -> 
          # Show button that opens URL in browser
        {:execute, execute_fn} -> 
          # Show button that calls execute_fn.()
      end

  """
  @spec action(Clarity.SourceLocation.t()) :: action_result()
  def action(%Clarity.SourceLocation{} = source_location) do
    case fetch_editor_config() do
      :error ->
        :editor_not_available

      {:ok, config} ->
        build_action(config, source_location)
    end
  end

  # Private functions

  @spec build_action(String.t() | atom(), Clarity.SourceLocation.t()) :: action_result()
  defp build_action(:url, %Clarity.SourceLocation{application: application} = source_location) do
    with {:ok, source_info} <- get_application_source_info(application),
         {:ok, relative_path} <- get_relative_path_for_source_location(source_location),
         {:ok, url_pattern} <- get_git_platform_pattern(source_info.source_url, source_info.ref) do
      line = Clarity.SourceLocation.line(source_location)

      url =
        url_pattern
        |> String.replace("%{path}", relative_path)
        |> String.replace("%{line}", Integer.to_string(line))

      full_url = source_info.source_url |> URI.merge(url) |> URI.to_string()
      {:url, full_url}
    else
      {:error, _reason} -> :action_not_available
    end
  end

  defp build_action(editor_command, source_location) do
    file_path = Clarity.SourceLocation.file_path(source_location)
    line = Clarity.SourceLocation.line(source_location)
    column = Clarity.SourceLocation.column(source_location) || 1

    case file_path do
      nil ->
        :action_not_available

      path ->
        substituted_command = substitute_template_vars(editor_command, path, line, column)
        execute_fn = fn -> execute_system_command(substituted_command) end
        {:execute, execute_fn}
    end
  end

  @spec fetch_editor_config() :: {:ok, String.t() | atom()} | :error
  defp fetch_editor_config do
    sources = [
      fn -> Application.fetch_env(:clarity, :editor) end,
      fn -> System.fetch_env("CLARITY_EDITOR") end,
      fn -> System.fetch_env("ELIXIR_EDITOR") end,
      fn -> System.fetch_env("EDITOR") end
    ]

    Enum.find_value(sources, :error, fn source ->
      case source.() do
        :error ->
          false

        {:ok, value} ->
          normalize_config_value(value)
      end
    end)
  end

  @spec normalize_config_value(term()) :: {:ok, String.t() | :url} | :error
  defp normalize_config_value(value)
  defp normalize_config_value(falsy) when falsy in [false, "false", "0", 0, "", nil], do: :error
  defp normalize_config_value(:url), do: {:ok, :url}

  defp normalize_config_value(value) when is_binary(value) do
    if String.match?(value, ~r/^__url__$/i), do: {:ok, :url}, else: {:ok, value}
  end

  @spec substitute_template_vars(String.t(), String.t(), pos_integer(), pos_integer()) ::
          String.t() | [String.t()]
  defp substitute_template_vars(command, file_path, line, column) do
    replacements = %{
      ~r/__file__/i => file_path,
      ~r/__line__/i => Integer.to_string(line),
      ~r/__column__/i => Integer.to_string(column)
    }

    if Enum.any?(replacements, fn {regex, _} -> Regex.match?(regex, command) end) do
      Enum.reduce(replacements, command, fn {regex, replacement}, acc ->
        String.replace(acc, regex, replacement)
      end)
    else
      [command, file_path]
    end
  end

  @spec execute_system_command(String.t() | [String.t()]) :: :ok | {:error, term()}
  defp execute_system_command(command)

  defp execute_system_command(command) when is_binary(command) do
    case System.cmd("sh", ["-c", command], stderr_to_stdout: true) do
      {_output, 0} ->
        :ok

      {error_output, exit_code} ->
        {:error, {:command_failed, exit_code, error_output}}
    end
  end

  defp execute_system_command([editor | args]) do
    case System.cmd(editor, args, stderr_to_stdout: true) do
      {_output, 0} ->
        :ok

      {error_output, exit_code} ->
        {:error, {:command_failed, exit_code, error_output}}
    end
  end

  @spec get_relative_path_for_source_location(Clarity.SourceLocation.t()) ::
          {:ok, String.t()} | {:error, term()}
  defp get_relative_path_for_source_location(source_location) do
    case Clarity.SourceLocation.file_path(source_location, :app) do
      nil -> {:error, :no_file_path}
      path -> {:ok, path}
    end
  end

  @spec get_application_source_info(atom() | nil) ::
          {:ok, %{source_url: String.t(), ref: String.t()}} | {:error, term()}
  defp get_application_source_info(nil), do: {:error, :no_application}

  defp get_application_source_info(app) do
    with :ok <- ensure_mix_running(),
         {:ok, source_info} <- mix_source_info(app) do
      {:ok, source_info}
    else
      {:error, _reason} = error -> error
    end
  end

  @spec ensure_mix_running() :: :ok | {:error, :mix_not_running}
  defp ensure_mix_running do
    Application.started_applications()
    |> Enum.any?(&match?({:mix, _description, _version}, &1))
    |> if do
      :ok
    else
      {:error, :mix_not_running}
    end
  end

  @spec mix_source_info(Application.app()) ::
          {:ok, %{source_url: String.t(), ref: String.t()}} | {:error, term()}
  defp mix_source_info(app) do
    with {:ok, project_module} <- mix_project_module(app) do
      project_info = project_module.project()

      docs_info =
        case Keyword.fetch(project_info, :docs) do
          {:ok, docs} when is_list(docs) -> docs
          {:ok, docs} when is_function(docs, 0) -> docs.()
          _ -> []
        end

      source_url = Keyword.get(docs_info, :source_url) || Keyword.get(project_info, :source_url)

      ref =
        Keyword.get(docs_info, :source_ref) || Keyword.get(project_info, :source_ref) || "main"

      if source_url do
        source_url =
          if String.ends_with?(source_url, "/"), do: source_url, else: source_url <> "/"

        {:ok, %{source_url: source_url, ref: ref}}
      else
        {:error, {:no_source_url, app}}
      end
    end
  end

  @spec mix_project_module(Application.app()) :: {:ok, module()} | {:error, term()}
  defp mix_project_module(app) do
    project =
      if Mix.Project.config()[:app] == app do
        Mix.Project.get()
      else
        case Mix.Project.deps_paths() do
          %{^app => path} ->
            Mix.Project.in_project(app, path, fn _ -> Mix.Project.get() end)

          _ ->
            nil
        end
      end

    case project do
      nil -> {:error, {:no_source_url, app}}
      module -> {:ok, module}
    end
  end

  @spec get_git_platform_pattern(String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  defp get_git_platform_pattern(source_url, ref) do
    uri = URI.parse(source_url)

    case uri.host do
      "github.com" ->
        {:ok, "blob/#{ref}/%{path}#L%{line}"}

      "gitlab.com" ->
        {:ok, "blob/#{ref}/%{path}#L%{line}"}

      "bitbucket.org" ->
        {:ok, "src/#{ref}/%{path}#cl-%{line}"}

      _ ->
        # Generic fallback for other platforms
        {:ok, "tree/#{ref}/%{path}#L%{line}"}
    end
  end
end
