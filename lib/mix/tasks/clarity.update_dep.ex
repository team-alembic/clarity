if Code.ensure_loaded?(Igniter.Mix.Task) do
  defmodule Mix.Tasks.Clarity.UpdateDep do
    @moduledoc """
    Updates the version requirement for a dependency in `mix.exs` via igniter.

        mix clarity.update_dep mdex "~> 0.14"

    Internal helper for Clarity's dependency update action — no `@shortdoc`, so
    it stays out of `mix help`.
    """

    use Igniter.Mix.Task

    alias Igniter.Project.Deps

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :clarity,
        example: ~s(mix clarity.update_dep mdex "~> 0.14"),
        positional: [:package, :requirement]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      %{package: package, requirement: requirement} = igniter.args.positional
      Deps.add_dep(igniter, {String.to_existing_atom(package), requirement}, yes?: true)
    end
  end
end
