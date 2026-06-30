defmodule Clarity.Dependency.Updater do
  @moduledoc """
  Updates a dependency in the development environment and hot-reloads it without
  a server restart.

  Steps: optionally widen the `mix.exs` requirement (via the `clarity.update_dep`
  igniter task), then `deps.update` + `deps.compile` the dependency, then stop,
  unload and restart its application so the new version is running.

  Dev-only and best-effort: dependencies with native (NIF) code may not fully
  reload until a real restart.
  """

  @doc """
  Updates `app`, first widening its `mix.exs` requirement to `requirement` when
  given (needed when the latest version is outside the current constraint).

  Compiled to a no-op returning `{:error, :not_dev}` outside the dev environment,
  so it can never run mix tasks or reload applications in test or a release.
  """
  @spec update(atom(), String.t() | nil) :: :ok | {:error, term()}
  def update(app, requirement \\ nil)

  # Mix.env/0 at module level is compile-time and release-safe; deps compile in
  # the consumer's build env, so this gates on *their* env.
  if Mix.env() == :dev do
    def update(app, requirement) do
      with :ok <- maybe_widen(app, requirement),
           :ok <- run("deps.update", [to_string(app)]),
           :ok <- run("deps.compile", [to_string(app)]) do
        reload(app)
      end
    rescue
      error -> {:error, Exception.message(error)}
    end

    @spec maybe_widen(atom(), String.t() | nil) :: :ok
    defp maybe_widen(_app, nil), do: :ok

    defp maybe_widen(app, requirement),
      do: run("clarity.update_dep", [to_string(app), requirement])

    @spec run(String.t(), [String.t()]) :: :ok
    defp run(task, args) do
      Mix.Task.rerun(task, args)
      :ok
    end

    @spec reload(atom()) :: :ok | {:error, term()}
    defp reload(app) do
      _ = Application.stop(app)
      _ = Application.unload(app)

      case Application.ensure_all_started(app) do
        {:ok, _started} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  else
    def update(_app, _requirement), do: {:error, :not_dev}
  end
end
