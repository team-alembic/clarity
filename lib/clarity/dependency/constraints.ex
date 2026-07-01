defmodule Clarity.Dependency.Constraints do
  @moduledoc """
  Version requirements for the project's *direct* dependencies, read from
  `mix.exs` via `Mix.Project.config/0`.

  Only direct dependencies carry a requirement here. A transitive dependency, a
  git/path dependency, or anything read outside a Mix context (e.g. a release)
  returns `nil` — its version isn't governed by this project's `mix.exs`.
  """

  @doc "The `mix.exs` version requirement for `app`, or `nil` when it isn't directly constrained."
  @spec requirement(atom()) :: String.t() | nil
  def requirement(app) do
    Enum.find_value(deps(), fn dep -> match_requirement(dep, app) end)
  end

  @spec deps() :: [tuple()]
  defp deps do
    if Code.ensure_loaded?(Mix.Project) and function_exported?(Mix.Project, :config, 0) do
      Mix.Project.config()[:deps] || []
    else
      []
    end
  rescue
    _error -> []
  end

  @spec match_requirement(tuple(), atom()) :: String.t() | nil
  defp match_requirement({app, requirement}, app) when is_binary(requirement), do: requirement

  defp match_requirement({app, requirement, opts}, app)
       when is_binary(requirement) and is_list(opts), do: requirement

  defp match_requirement(_dep, _app), do: nil
end
