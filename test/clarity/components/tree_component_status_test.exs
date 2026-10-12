defmodule Clarity.TreeComponentStatusTest do
  # async: false — registers a provider in the global :clarity_status_providers env.
  use ExUnit.Case, async: false

  alias Clarity.Graph
  alias Clarity.Perspective.Lensmaker
  alias Clarity.Status
  alias Clarity.TreeComponent
  alias Clarity.Vertex
  alias Phoenix.LiveView.Socket

  defmodule BackgroundProvider do
    @moduledoc false
    @behaviour Status.Provider

    # Stands in for a provider whose statuses come from data fetched in the
    # background, as Clarity.Status.SupplyChain's version status does.
    @impl Status.Provider
    def statuses(%Vertex.Application{app: :fetched}, _graph) do
      for message <- Application.get_env(:clarity, :test_fetched_statuses, []),
          do: %Status{severity: :warning, class: :hygiene, message: message, source: __MODULE__}
    end

    def statuses(_vertex, _graph), do: []

    @impl Status.Provider
    def version, do: Application.get_env(:clarity, :test_fetched_version)
  end

  setup do
    original = Application.fetch_env(:clarity, :clarity_status_providers)
    Application.put_env(:clarity, :clarity_status_providers, [BackgroundProvider])

    on_exit(fn ->
      Application.delete_env(:clarity, :test_fetched_statuses)
      Application.delete_env(:clarity, :test_fetched_version)

      case original do
        {:ok, value} -> Application.put_env(:clarity, :clarity_status_providers, value)
        :error -> Application.delete_env(:clarity, :clarity_status_providers)
      end
    end)

    app = %Vertex.Application{app: :fetched, description: "Fetched", version: "1.0.0"}
    graph = Graph.new()
    Graph.add_vertex(graph, app, %Vertex.Root{})
    Graph.add_edge(graph, %Vertex.Root{}, app, :application)

    {:ok, lens} = Lensmaker.get_lens_by_id("debug")

    assigns = %{
      id: "tree",
      graph: graph,
      lens: %{lens | status_filter: fn _status -> true end},
      prefix: "/",
      active_vertex: app,
      breadcrumbs: [%Vertex.Root{}, app],
      opened: MapSet.new(),
      collapsed: MapSet.new(),
      name_style: :short
    }

    {:ok, assigns: assigns}
  end

  test "keeps the status index while the graph is unchanged, until a provider's version changes",
       %{assigns: assigns} do
    Application.put_env(:clarity, :test_fetched_statuses, [])
    socket = update(assigns, %Socket{})
    refute Map.has_key?(socket.assigns.status_index, "application:fetched")

    # The data changes, but the provider hasn't said so: the index is kept.
    Application.put_env(:clarity, :test_fetched_statuses, ["Newer version 2.0.0 available"])
    socket = update(assigns, socket)
    refute Map.has_key?(socket.assigns.status_index, "application:fetched")

    Application.put_env(:clarity, :test_fetched_version, 1)
    socket = update(assigns, socket)

    assert %{severity: :warning, issues: [%{message: "Newer version 2.0.0 available"}]} =
             socket.assigns.status_index["application:fetched"]
  end

  @spec update(map(), Socket.t()) :: Socket.t()
  defp update(assigns, socket) do
    {:ok, socket} = TreeComponent.update(assigns, socket)
    socket
  end
end
