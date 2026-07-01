defmodule Clarity.Status.SupplyChain do
  @moduledoc """
  Flags application vertices with supply-chain statuses:

  - `:security` / `:error` — the application has one or more security advisories.
  - `:hygiene` / `:warning` — the installed version is retired on Hex.
  - `:hygiene` / `:info` — a newer version is published on Hex.

  Advisories are read from the graph's `:advisory` edges; version status from
  `Clarity.Dependency.Registry`. An application can carry both a security and a
  hygiene status at once.
  """

  @behaviour Clarity.Status.Provider

  alias Clarity.Dependency
  alias Clarity.Dependency.Registry
  alias Clarity.Graph
  alias Clarity.Status
  alias Clarity.Vertex

  @impl Clarity.Status.Provider
  def statuses(%Vertex.Application{app: app, version: version} = vertex, graph) do
    advisory_statuses(graph, vertex) ++ version_statuses(app, to_string(version))
  end

  def statuses(_vertex, _graph), do: []

  @spec advisory_statuses(Graph.t(), Vertex.Application.t()) :: [Status.t()]
  defp advisory_statuses(graph, vertex) do
    case Graph.out_degree(graph, vertex, :advisory) do
      0 ->
        []

      count ->
        [
          %Status{
            severity: :error,
            class: :security,
            message: advisory_message(count),
            source: __MODULE__
          }
        ]
    end
  end

  @spec advisory_message(pos_integer()) :: String.t()
  defp advisory_message(1), do: "1 known security advisory"
  defp advisory_message(count), do: "#{count} known security advisories"

  @spec version_statuses(atom(), String.t()) :: [Status.t()]
  defp version_statuses(app, installed) do
    case Registry.summary(app) do
      %{latest: latest, retired: retired} -> version_statuses(installed, latest, retired)
      nil -> []
    end
  end

  @spec version_statuses(String.t(), String.t() | nil, [String.t()]) :: [Status.t()]
  defp version_statuses(installed, latest, retired) do
    cond do
      installed in retired ->
        [
          %Status{
            severity: :warning,
            class: :hygiene,
            message: "Installed version #{installed} is retired",
            source: __MODULE__
          }
        ]

      Dependency.outdated?(installed, latest) ->
        [
          %Status{
            severity: :info,
            class: :hygiene,
            message: "Newer version #{latest} available (installed #{installed})",
            source: __MODULE__
          }
        ]

      true ->
        []
    end
  end
end
