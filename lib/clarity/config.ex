defmodule Clarity.Config do
  @moduledoc """
  Configuration utilities for Clarity.

  ## Application Filtering

  Clarity can be configured to include or exclude specific applications from introspection
  to improve performance. By default, when no configuration is provided, all OTP and Elixir
  standard library applications are excluded.

  ### Configuration

  Set the `:introspector_applications` key in your Clarity configuration:

  ```elixir
  # Include only specific applications
  config :clarity, :introspector_applications, [:my_app, :phoenix, :ecto]
  ```

  When `:introspector_applications` is:
  - A list of atoms - Only these applications will be introspected (include mode)
  - `nil` or not set - All applications except OTP/Elixir standard libraries will be introspected

  This configuration affects:
  - Which application vertices are created in the graph
  - Which code reload events are processed
  """

  @typedoc false
  @type application_details :: {Application.app(), description :: charlist(), vsn :: charlist()}

  @doc false
  @spec filtered_applications() :: [application_details()]
  def filtered_applications do
    filter_by_config(Application.loaded_applications())
  end

  @doc false
  @spec should_process_app?(Application.app()) :: boolean()
  def should_process_app?(app) do
    case get_filter_config() do
      {:include, apps} -> app in apps
      {:exclude, apps} -> app not in apps
    end
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

  @spec get_filter_config() :: {:include, [Application.app()]} | {:exclude, [Application.app()]}
  defp get_filter_config do
    case Application.get_env(:clarity, :introspector_applications) do
      nil ->
        # Default exclusion list when no configuration is provided
        {:exclude, @otp_apps ++ @elixir_apps}

      apps when is_list(apps) ->
        {:include, apps}
    end
  end
end
