defmodule Clarity.Dependency do
  @moduledoc """
  Version-status helpers for a dependency, derived from the bulk Hex registry.

  The registry lists each package's versions (ascending) and the indices of
  retired versions. `summarise/1` reduces that to the latest *stable* version and
  the set of retired version strings; `outdated?/2` compares an installed version
  against the latest.
  """

  @type summary() :: %{latest: String.t() | nil, retired: [String.t()]}

  @doc """
  Reduces a registry package entry to its version status.

  `latest` is the highest non-prerelease, non-retired version (or `nil`).
  """
  @spec summarise(%{
          required(:versions) => [String.t()],
          optional(:retired) => [non_neg_integer()]
        }) ::
          summary()
  def summarise(%{versions: versions} = package) do
    retired =
      package
      |> Map.get(:retired, [])
      |> Enum.map(&Enum.at(versions, &1))
      |> Enum.reject(&is_nil/1)

    %{latest: latest_stable(versions, retired), retired: retired}
  end

  @doc "Whether `installed` is behind `latest` (false when either is unknown/unparseable)."
  @spec outdated?(String.t(), String.t() | nil) :: boolean()
  def outdated?(_installed, nil), do: false
  def outdated?(installed, latest), do: compare(installed, latest) == :lt

  @typedoc """
  How an update to `latest` relates to the dependency's `mix.exs` constraint.

  - `:up_to_date` — already on the latest stable version
  - `{:updatable, latest}` — latest satisfies the constraint, so `mix deps.update`
    will move to it
  - `{:constraint_blocks, latest, requirement}` — latest is outside the
    constraint, so the requirement in `mix.exs` must be widened first
  - `{:unconstrained, latest}` — no direct constraint (e.g. a transitive dep),
    so the update is governed by its dependents, not your `mix.exs`
  """
  @type update_status() ::
          :up_to_date
          | {:updatable, String.t()}
          | {:constraint_blocks, String.t(), String.t()}
          | {:unconstrained, String.t()}

  @doc """
  Classifies how `installed` can reach `latest` given the `mix.exs` `requirement`
  (or `nil` when the dependency isn't directly constrained).
  """
  @spec update_status(String.t(), String.t() | nil, String.t() | nil) :: update_status()
  def update_status(installed, latest, requirement) do
    cond do
      not outdated?(installed, latest) -> :up_to_date
      is_nil(requirement) -> {:unconstrained, latest}
      satisfies?(latest, requirement) -> {:updatable, latest}
      true -> {:constraint_blocks, latest, requirement}
    end
  end

  @doc """
  The `mix.exs` requirement to set so a constraint-blocked update becomes
  installable, or `nil` when no widening is needed.
  """
  @spec widen_requirement(update_status()) :: String.t() | nil
  def widen_requirement({:constraint_blocks, latest, _requirement}) do
    case Version.parse(latest) do
      {:ok, %Version{major: major, minor: minor}} -> "~> #{major}.#{minor}"
      :error -> nil
    end
  end

  def widen_requirement(_status), do: nil

  @spec satisfies?(String.t(), String.t()) :: boolean()
  defp satisfies?(version, requirement) do
    match?({:ok, true}, safe_match(version, requirement))
  end

  @spec safe_match(String.t(), String.t()) :: {:ok, boolean()} | :error
  defp safe_match(version, requirement) do
    {:ok, Version.match?(version, requirement)}
  rescue
    Version.InvalidVersionError -> :error
    Version.InvalidRequirementError -> :error
  end

  @spec latest_stable([String.t()], [String.t()]) :: String.t() | nil
  defp latest_stable(versions, retired) do
    versions
    |> Enum.reject(&(&1 in retired))
    |> Enum.filter(&stable?/1)
    |> Enum.reduce(nil, fn version, latest ->
      if is_nil(latest) or compare(version, latest) == :gt, do: version, else: latest
    end)
  end

  @spec stable?(String.t()) :: boolean()
  defp stable?(version) do
    match?({:ok, %Version{pre: []}}, Version.parse(version))
  end

  @spec compare(String.t(), String.t()) :: :lt | :eq | :gt
  defp compare(left, right) do
    with {:ok, parsed_left} <- Version.parse(left),
         {:ok, parsed_right} <- Version.parse(right) do
      Version.compare(parsed_left, parsed_right)
    else
      _error -> :eq
    end
  end
end
