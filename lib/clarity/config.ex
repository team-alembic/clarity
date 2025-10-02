defmodule Clarity.Config do
  @moduledoc """
  Centralized configuration management for Clarity.

  This module provides a single source of truth for all Clarity configuration settings,
  handling both global application settings and per-application extension configurations.

  ## Global Configuration Settings

  These settings are configured on the `:clarity` application:

  ### Application Filtering (`:introspector_applications`)

  Controls which applications are introspected to improve performance:

  ```elixir
  # Include only specific applications
  config :clarity, :introspector_applications, [:my_app, :phoenix, :ecto]
  ```

  When `:introspector_applications` is:
  - A list of atoms - Only these applications will be introspected (include mode)
  - `nil` or not set - All applications except OTP/Elixir standard libraries will be introspected

  This affects which application vertices are created and which code reload events are processed.

  ### Editor Configuration (`:editor`)

  Controls how files are opened from Clarity. Supports both local editor commands and URL mode:

  ```elixir
  # Local editor with template variables
  config :clarity, :editor, "code --goto __FILE__:__LINE__:__COLUMN__"
  config :clarity, :editor, "subl __FILE__:__LINE__"

  # URL mode for browser-based editing (use atom in config)
  config :clarity, :editor, :url
  ```

  ```bash
  # Environment variables (use string since atoms aren't available)
  export CLARITY_EDITOR="code --goto __FILE__:__LINE__:__COLUMN__"
  export CLARITY_EDITOR="__URL__"  # URL mode via environment variable
  ```

  **Configuration Priority:** (highest to lowest)
  1. `config :clarity, editor: ...`
  2. `CLARITY_EDITOR` environment variable
  3. `ELIXIR_EDITOR` environment variable
  4. `EDITOR` environment variable

  **Template Variables:** (case-insensitive)
  - `__FILE__` - replaced with the file path
  - `__LINE__` - replaced with the line number
  - `__COLUMN__` - replaced with the column number

  > #### Security Warning {: .warning}
  >
  > Editor configuration executes system commands based on user configuration.
  > Ensure configured commands are safe and trusted. For untrusted environments,
  > use URL mode (`:url` or `"__URL__"`).

  ### Default Perspective Lens (`:default_perspective_lens`)

  Sets the initial lens when starting a perspective:

  ```elixir
  config :clarity, :default_perspective_lens, "debug"
  ```

  ## Per-Application Extension Settings

  These settings are configured on individual applications:

  ### Lensmaker Registration (`:clarity_perspective_lensmakers`)

  Applications can register lensmakers for the perspective system:

  ```elixir
  config :my_app, :clarity_perspective_lensmakers, [
    MyApp.SecurityLensmaker,
    MyApp.CustomExtension
  ]
  ```

  ### Custom Introspector Registration (`:clarity_introspectors`)

  Applications can register custom introspectors:

  ```elixir
  config :my_app, :clarity_introspectors, [
    MyApp.MyCustomIntrospector
  ]
  ```

  ### Content Provider Registration (`:clarity_content_providers`)

  Applications can register custom content providers:

  ```elixir
  config :my_app, :clarity_content_providers, [
    MyApp.CustomContent,
    MyApp.InteractiveContent
  ]
  ```
  """

  @typedoc false
  @type application_details :: {Application.app(), description :: charlist(), vsn :: charlist()}

  @doc false
  @spec filtered_applications() :: [application_details()]
  def filtered_applications do
    filter_by_config(Application.loaded_applications())
  end

  @doc """
  Checks if an application should be processed based on `:introspector_applications` configuration.
  """
  @spec should_process_app?(Application.app()) :: boolean()
  def should_process_app?(app) do
    case get_filter_config() do
      {:include, apps} -> app in apps
      {:exclude, apps} -> app not in apps
    end
  end

  @doc """
  Checks if a module should be processed based on `:introspector_applications` configuration.

  Returns `false` if the module doesn't belong to any application.
  """
  @spec should_process_module?(module()) :: boolean()
  def should_process_module?(module) do
    case Application.get_application(module) do
      nil -> false
      app -> should_process_app?(app)
    end
  end

  @doc false
  @spec fetch_editor_config() :: {:ok, String.t() | atom()} | :error
  def fetch_editor_config do
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
          normalize_editor_config_value(value)
      end
    end)
  end

  @doc false
  @spec list_lensmakers() :: [module()]
  def list_lensmakers do
    Application.loaded_applications()
    |> Enum.map(&elem(&1, 0))
    |> Enum.flat_map(&Application.get_env(&1, :clarity_perspective_lensmakers, []))
    |> Enum.uniq()
  end

  @doc false
  @spec list_introspectors() :: [module()]
  def list_introspectors do
    Application.loaded_applications()
    |> Enum.map(&elem(&1, 0))
    |> Enum.flat_map(&Application.get_all_env/1)
    |> Keyword.get_values(:clarity_introspectors)
    |> List.flatten()
    |> Enum.uniq()
  end

  @doc false
  @spec list_content_providers() :: [module()]
  def list_content_providers do
    Application.loaded_applications()
    |> Enum.map(&elem(&1, 0))
    |> Enum.flat_map(&Application.get_env(&1, :clarity_content_providers, []))
    |> Enum.uniq()
  end

  @doc false
  @spec fetch_default_perspective_lens!() :: String.t()
  def fetch_default_perspective_lens! do
    Application.fetch_env!(:clarity, :default_perspective_lens)
  end

  @spec filter_by_config([application_details()]) :: [application_details()]
  defp filter_by_config(loaded_applications) do
    case get_filter_config() do
      {:include, apps} ->
        Enum.filter(loaded_applications, fn {app, _, _} -> app in apps end)

      {:exclude, apps} ->
        Enum.reject(loaded_applications, fn {app, _, _} -> app in apps end)
    end
  end

  otp_apps =
    :code.root_dir()
    |> to_string()
    |> Path.join("lib")
    |> File.ls!()
    # drop -<vsn>
    |> Enum.map(&String.replace(&1, ~r/-\d.*$/, ""))
    |> Enum.uniq()
    |> Enum.map(&String.to_atom/1)
    |> Enum.sort()

  @otp_apps otp_apps

  @elixir_apps ~w(eex elixir ex_unit iex logger mix)a

  @hex_apps ~w(hex)a

  @spec get_filter_config() :: {:include, [Application.app()]} | {:exclude, [Application.app()]}
  defp get_filter_config do
    case Application.get_env(:clarity, :introspector_applications) do
      nil ->
        # Default exclusion list when no configuration is provided
        {:exclude, @otp_apps ++ @elixir_apps ++ @hex_apps}

      apps when is_list(apps) ->
        {:include, apps}
    end
  end

  @spec normalize_editor_config_value(term()) :: {:ok, String.t() | :url} | :error
  defp normalize_editor_config_value(value)

  defp normalize_editor_config_value(falsy) when falsy in [false, "false", "0", 0, "", nil],
    do: :error

  defp normalize_editor_config_value(:url), do: {:ok, :url}

  defp normalize_editor_config_value(value) when is_binary(value) do
    if String.match?(value, ~r/^__url__$/i), do: {:ok, :url}, else: {:ok, value}
  end
end
