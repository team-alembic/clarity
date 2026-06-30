defmodule Clarity.Dependency.Updater do
  @moduledoc """
  Updates a dependency in the development environment, leaving the project
  compiled and ready for the caller to reboot.

  Steps: optionally widen the `mix.exs` requirement (via the `clarity.update_dep`
  igniter task), then `deps.update` + `deps.compile` the dependency, then a full
  `mix compile` so the project is rebuilt against it and the compile manifest is
  fresh (otherwise Phoenix's stale-config check raises after the reboot).

  A running BEAM can't hot-swap dependency code (and NIFs can't reload at all),
  so the caller restarts the VM (`System.restart/0`) to actually load the new
  version. Dev-only.
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
      with :ok <- ensure_hex(),
           :ok <- maybe_widen(app, requirement),
           :ok <- run("deps.update", [to_string(app)]),
           :ok <- run("deps.compile", [to_string(app)]) do
        run("compile", [])
      end
    rescue
      error -> {:error, Exception.message(error)}
    end

    # A running app (unlike a `mix` CLI run) hasn't added the archive paths, so
    # Hex's own modules aren't loadable and `deps.update` fails reaching them.
    # Bootstrap the archives and start Hex before fetching.
    @spec ensure_hex() :: :ok
    defp ensure_hex do
      Mix.Local.append_archives()
      Mix.Hex.start()
      :ok
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
  else
    def update(_app, _requirement), do: {:error, :not_dev}
  end
end
