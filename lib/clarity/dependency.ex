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
