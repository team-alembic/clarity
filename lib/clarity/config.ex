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

  ### Introspection Order

  Clarity introspects the project's own applications first (see
  `project_applications/0`), so their Ash domains, resources and the like
  appear soon after it starts, and then their dependencies, in the
  background. A dependency comes sooner when an introspector needs one of its
  modules (say, an Ash type or a Spark DSL), or when someone navigates to it.

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

  ### Cache Path (`:cache_path`)

  Sets the directory where the graph cache is stored:

  ```elixir
  config :clarity, :cache_path, "/custom/cache/path"
  ```

  Defaults to `Application.app_dir(:clarity, "priv/cache")` if not configured.

  ### Lockfile (`:lockfile`)

  The `mix.lock` that says which applications are Hex packages, for version
  status and advisories:

  ```elixir
  config :clarity, :lockfile, "../../mix.lock"
  ```

  Defaults to the Mix project's lockfile.

  ### Auto Start (`:auto_start?`)

  Controls whether Clarity automatically starts introspection on application startup:

  ```elixir
  config :clarity, :auto_start?, false
  ```

  When `true` (default), Clarity loads the cache and starts introspection immediately on startup.

  When `false`, Clarity defers initialization until the first call to `Clarity.get/1` or
  `Clarity.introspect(:full)`. This is useful for:
  - Faster application startup in development
  - Avoiding unnecessary introspection in test environment
  - Manual control over when introspection begins

  **Note:** When auto-start is disabled, incremental rebuild calls (triggered by code
  reloading) are silently ignored until initialization is triggered.

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

  ### Status Provider Registration (`:clarity_status_providers`)

  Applications can register custom status providers:

  ```elixir
  config :my_app, :clarity_status_providers, [
    MyApp.LicenceStatus
  ]
  ```

  ### Report Registration (`:clarity_reports`)

  Applications can register custom reports:

  ```elixir
  config :my_app, :clarity_reports, [
    MyApp.Report.Compliance
  ]
  ```
  """

  @typedoc false
  @type application_details :: {Application.app(), description :: charlist(), vsn :: charlist()}

  @doc false
  @spec filtered_applications() :: [application_details()]
  def filtered_applications do
    filter_by_config(Application.started_applications())
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
    case application_of(module) do
      nil -> false
      app -> should_process_app?(app)
    end
  end

  @doc """
  Returns the applications of the project Clarity runs in, which it
  introspects before their dependencies, or `:all` when it can't tell (in a
  release, say, without Mix).

  They are the project's own (each of an umbrella's) and those of its path
  dependencies: the code being worked on, rather than packages fetched into
  `deps`.
  """
  @spec project_applications() :: MapSet.t(Application.app()) | :all
  def project_applications do
    if Code.ensure_loaded?(Mix.Project) and Mix.Project.get() != nil do
      deps_path = Path.expand(Mix.Project.deps_path())

      path_deps =
        for {app, path} <- Mix.Project.deps_paths(),
            not String.starts_with?(Path.expand(path), deps_path <> "/"),
            do: app

      own = Mix.Project.config()[:app] |> List.wrap() |> Enum.reject(&is_nil/1)
      umbrella = Map.keys(Mix.Project.apps_paths() || %{})

      MapSet.new(own ++ umbrella ++ path_deps)
    else
      :all
    end
  end

  @doc """
  Returns whether `app` is one of the project's own, in
  `project_applications/0`, rather than a dependency fetched into `deps`, from
  Hex or git: its to-dos are yours, and its architecture is the project's.
  In a release, without Mix to tell, every application is.

  Pass `project_applications/0` when asking about many, to work it out once.
  """
  @spec own_application?(Application.app(), MapSet.t(Application.app()) | :all) :: boolean()
  def own_application?(app, project_apps \\ project_applications())
  def own_application?(_app, :all), do: true
  def own_application?(app, project_apps), do: MapSet.member?(project_apps, app)

  @doc """
  Returns whether `module` is the project's own, as `own_application?/2`
  says of its application. A module in no application, such as one compiled
  at runtime, is taken to be.
  """
  @spec own_module?(module(), MapSet.t(Application.app()) | :all) :: boolean()
  def own_module?(module, project_apps \\ project_applications()) do
    case application_of(module) do
      nil -> true
      app -> own_application?(app, project_apps)
    end
  end

  @module_applications Module.concat(__MODULE__, ModuleApplications)

  @doc """
  Returns the application `module` belongs to, like `Application.get_application/1`.

  That searches every loaded application's modules each time, which adds up
  over thousands of modules, so the answers are kept: the first module it
  hasn't seen has it note the application of every loaded module.
  `forget_module_applications/0` starts over, for when modules are compiled.
  """
  @spec application_of(module()) :: Application.app() | nil
  def application_of(module) do
    case :ets.whereis(@module_applications) do
      :undefined -> Application.get_application(module)
      table -> cached_application_of(table, module)
    end
  end

  @doc false
  @spec create_module_application_cache() :: :ets.table()
  def create_module_application_cache do
    :ets.new(@module_applications, [:named_table, :public, :set, read_concurrency: true])
  end

  @doc false
  @spec forget_module_applications() :: :ok
  def forget_module_applications do
    if :ets.whereis(@module_applications) != :undefined,
      do: :ets.delete_all_objects(@module_applications)

    :ok
  end

  @spec cached_application_of(:ets.table(), module()) :: Application.app() | nil
  defp cached_application_of(table, module) do
    case :ets.lookup(table, module) do
      [{^module, app}] ->
        app

      [] ->
        entries =
          for {app, _description, _vsn} <- Application.loaded_applications(),
              app_module <- Application.spec(app, :modules) || [],
              do: {app_module, app}

        :ets.insert(table, entries)
        # Nor is it asked again, until modules are compiled.
        if :ets.insert_new(table, {module, nil}),
          do: nil,
          else: :ets.lookup_element(table, module, 2)
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
  # Clarity's own lenses come first, in the order it lists them, then the
  # other applications', by application name: the activity bar shows them in
  # this order, and the loaded applications come in none in particular.
  @spec list_lensmakers() :: [module()]
  def list_lensmakers do
    others =
      Application.loaded_applications()
      |> Enum.map(&elem(&1, 0))
      |> List.delete(:clarity)
      |> Enum.sort()

    [:clarity | others]
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
    |> Enum.filter(&Code.ensure_loaded?/1)
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
  @spec list_status_providers() :: [module()]
  def list_status_providers do
    Application.loaded_applications()
    |> Enum.map(&elem(&1, 0))
    |> Enum.flat_map(&Application.get_env(&1, :clarity_status_providers, []))
    |> Enum.uniq()
    |> Enum.filter(&Code.ensure_loaded?/1)
  end

  @doc false
  @spec list_reports() :: [module()]
  def list_reports do
    Application.loaded_applications()
    |> Enum.map(&elem(&1, 0))
    |> Enum.flat_map(&Application.get_env(&1, :clarity_reports, []))
    |> Enum.uniq()
  end

  @doc false
  @spec fetch_default_perspective_lens!() :: String.t()
  def fetch_default_perspective_lens! do
    Application.fetch_env!(:clarity, :default_perspective_lens)
  end

  @doc false
  @spec lockfile() :: Path.t() | nil
  def lockfile, do: Application.get_env(:clarity, :lockfile)

  @doc false
  @spec cache_path() :: Path.t()
  def cache_path do
    Application.get_env(:clarity, :cache_path, Application.app_dir(:clarity, "priv/cache"))
  end

  @doc false
  @spec auto_start?() :: boolean()
  def auto_start? do
    Application.get_env(:clarity, :auto_start?, false)
  end

  @doc false
  @spec advisories_enabled?() :: boolean()
  def advisories_enabled?, do: advisories_config(:enabled?, true)

  @doc false
  @spec advisories_refresh_interval() :: pos_integer()
  def advisories_refresh_interval, do: advisories_config(:refresh_interval, to_timeout(day: 1))

  @doc false
  @spec advisories_source_url() :: String.t()
  def advisories_source_url do
    advisories_config(
      :source_url,
      "https://osv-vulnerabilities.storage.googleapis.com/Hex/all.zip"
    )
  end

  @doc false
  @spec hex_registry_url() :: String.t()
  def hex_registry_url, do: advisories_config(:hex_registry_url, "https://repo.hex.pm/versions")

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

  @spec advisories_config(atom(), term()) :: term()
  defp advisories_config(key, default) do
    :clarity |> Application.get_env(:advisories, []) |> Keyword.get(key, default)
  end
end
