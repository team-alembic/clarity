defmodule Clarity.Advisory do
  @moduledoc """
  A security advisory affecting a single Hex package, parsed from an OSV record.

  An OSV record can list several affected packages; `from_osv/1` splits it into
  one `Clarity.Advisory` per Hex package so advisories can be indexed and matched
  by package name. The display fields (`summary`, `severity`, `references`,
  `aliases`) are shared across the split; only `package`/`ranges`/`versions`
  differ, and they drive version matching via `affects_version?/2`.
  """

  @type t() :: %__MODULE__{
          id: String.t(),
          package: String.t(),
          summary: String.t() | nil,
          severity: String.t() | nil,
          ranges: [map()],
          versions: [String.t()],
          references: [String.t()],
          aliases: [String.t()]
        }

  @enforce_keys [:id, :package]
  defstruct [
    :id,
    :package,
    :summary,
    :severity,
    :aliases,
    ranges: [],
    versions: [],
    references: []
  ]

  @doc """
  Splits an OSV record into one advisory per affected Hex package.

  Non-Hex ecosystems are ignored.
  """
  @spec from_osv(map()) :: [t()]
  def from_osv(osv) when is_map(osv) do
    summary = osv["summary"] || osv["details"]
    severity = severity(osv)
    references = for %{"url" => url} <- osv["references"] || [], do: url
    aliases = osv["aliases"] || []

    for %{"package" => %{"ecosystem" => "Hex", "name" => name}} = affected <-
          osv["affected"] || [] do
      %__MODULE__{
        id: osv["id"],
        package: name,
        summary: summary,
        severity: severity,
        ranges: affected["ranges"] || [],
        versions: affected["versions"] || [],
        references: references,
        aliases: aliases
      }
    end
  end

  @doc """
  Whether `version` falls within the advisory's affected set.

  Unparseable versions never match, so the check fails closed (no false
  positives) rather than guessing.
  """
  @spec affects_version?(t(), String.t()) :: boolean()
  def affects_version?(%__MODULE__{versions: versions, ranges: ranges}, version) do
    version in versions or Enum.any?(ranges, &version_in_range?(version, &1))
  end

  @spec severity(map()) :: String.t() | nil
  defp severity(osv) do
    case osv["database_specific"] do
      %{"severity" => severity} when is_binary(severity) -> severity
      _other -> nil
    end
  end

  @spec version_in_range?(String.t(), map()) :: boolean()
  defp version_in_range?(version, %{"events" => events}) do
    events
    |> Enum.reduce_while("0", fn
      %{"introduced" => introduced}, _acc ->
        {:cont, introduced}

      %{"fixed" => fixed}, introduced ->
        if gte?(version, introduced) and lt?(version, fixed),
          do: {:halt, true},
          else: {:cont, "0"}

      %{"last_affected" => last}, introduced ->
        if gte?(version, introduced) and lte?(version, last),
          do: {:halt, true},
          else: {:cont, "0"}

      _event, introduced ->
        {:cont, introduced}
    end)
    |> Kernel.==(true)
  end

  defp version_in_range?(_version, _range), do: false

  @spec gte?(String.t(), String.t()) :: boolean()
  defp gte?(_version, "0"), do: true
  defp gte?(version, bound), do: compare(version, bound) in [:gt, :eq]

  @spec lt?(String.t(), String.t()) :: boolean()
  defp lt?(version, bound), do: compare(version, bound) == :lt

  @spec lte?(String.t(), String.t()) :: boolean()
  defp lte?(version, bound), do: compare(version, bound) in [:lt, :eq]

  @spec compare(String.t(), String.t()) :: :lt | :eq | :gt | :error
  defp compare(version, bound) do
    with {:ok, parsed_version} <- Version.parse(version),
         {:ok, parsed_bound} <- Version.parse(bound) do
      Version.compare(parsed_version, parsed_bound)
    else
      _error -> :error
    end
  end
end
