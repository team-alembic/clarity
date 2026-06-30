defmodule Clarity.Dependency.Updater do
  @moduledoc """
  Updates a dependency in the development environment, leaving the project
  compiled and ready for the caller to reboot.

  Steps: optionally widen the `mix.exs` requirement (via the `clarity.update_dep`
  igniter task), then `deps.update` the dependency, then a full `mix compile` so
  the project is rebuilt against it and the compile manifest is fresh (otherwise
  Phoenix's stale-config check raises after the reboot).

  Each step runs as a `mix` **subprocess**, not in-process: a `mix` CLI
  initialises Hex correctly, whereas running `deps.update` via `Mix.Task` inside
  the already-running app leaves Hex in a state where `Hex.Mix.to_lock/1` crashes
  trying to stringify a `Hex.Solver.Constraints.Range`. The subprocess writes the
  new `mix.lock` and compiles into the shared `_build`.

  A running BEAM can't hot-swap dependency code (and NIFs can't reload at all),
  so the caller restarts the VM (`System.restart/0`) to actually load the new
  version. Dev-only.
  """

  @doc """
  Updates `app`, first widening its `mix.exs` requirement to `requirement` when
  given (needed when the latest version is outside the current constraint).

  Compiled to a no-op returning `{:error, :not_dev}` outside the dev environment,
  so it can never shell out to mix in test or a release.
  """
  @spec update(atom(), String.t() | nil) :: :ok | {:error, term()}
  def update(app, requirement \\ nil)

  # Mix.env/0 at module level is compile-time and release-safe; deps compile in
  # the consumer's build env, so this gates on *their* env.
  if Mix.env() == :dev do
    def update(app, requirement) do
      with :ok <- maybe_widen(app, requirement),
           :ok <- mix(["deps.update", to_string(app)]) do
        mix(["compile"])
      end
    rescue
      error -> {:error, Exception.message(error)}
    end

    @spec maybe_widen(atom(), String.t() | nil) :: :ok | {:error, String.t()}
    defp maybe_widen(_app, nil), do: :ok

    defp maybe_widen(app, requirement),
      do: mix(["clarity.update_dep", to_string(app), requirement])

    @spec mix([String.t()]) :: :ok | {:error, String.t()}
    defp mix(args) do
      case System.cmd("mix", args,
             cd: File.cwd!(),
             env: [{"MIX_ENV", "dev"}],
             stderr_to_stdout: true
           ) do
        {_output, 0} ->
          :ok

        {output, status} ->
          {:error, "mix #{Enum.join(args, " ")} exited with #{status}\n\n#{tail(output)}"}
      end
    end

    @spec tail(String.t()) :: String.t()
    defp tail(output) do
      output |> String.split("\n", trim: true) |> Enum.take(-12) |> Enum.join("\n")
    end
  else
    def update(_app, _requirement), do: {:error, :not_dev}
  end
end
