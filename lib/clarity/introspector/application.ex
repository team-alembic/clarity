defmodule Clarity.Introspector.Application do
  @moduledoc false

  @behaviour Clarity.Introspector

  alias Clarity.Config
  alias Clarity.Vertex

  @impl Clarity.Introspector
  def source_vertex_types, do: [Clarity.Vertex.Root]

  @impl Clarity.Introspector
  def introspect_vertex(%Vertex.Root{} = root_vertex, graph) do
    current_apps = Config.filtered_applications()
    cached_apps = get_cached_applications(graph)

    current_apps_map = Map.new(current_apps, fn {app, _, _} = tuple -> {app, tuple} end)
    cached_apps_map = Map.new(cached_apps, fn vertex -> {vertex.app, vertex} end)

    purge_entries =
      Enum.flat_map(cached_apps, fn cached_vertex ->
        purge_app_if_changed(cached_vertex, current_apps_map)
      end)

    add_entries =
      Enum.flat_map(current_apps, fn app_tuple ->
        add_app_entries(app_tuple, cached_apps_map, root_vertex)
      end)

    {:ok, purge_entries ++ add_entries}
  end

  @spec get_cached_applications(Clarity.Graph.t()) :: [Vertex.Application.t()]
  defp get_cached_applications(graph) do
    Clarity.Graph.vertices(graph, type: Vertex.Application)
  end

  @spec purge_app_if_changed(
          Vertex.Application.t(),
          %{Application.app() => {Application.app(), charlist(), charlist()}}
        ) :: [Clarity.Introspector.entry()]
  defp purge_app_if_changed(cached_vertex, current_apps_map) do
    case Map.fetch(current_apps_map, cached_vertex.app) do
      {:ok, app_tuple} ->
        current_vertex = Vertex.Application.from_app_tuple(app_tuple)

        if cached_vertex.version == current_vertex.version do
          []
        else
          [{:purge, cached_vertex}]
        end

      :error ->
        [{:purge, cached_vertex}]
    end
  end

  @spec add_app_entries(
          {Application.app(), charlist(), charlist()},
          %{Application.app() => Vertex.Application.t()},
          Vertex.Root.t()
        ) :: [Clarity.Introspector.entry()]
  defp add_app_entries(app_tuple, cached_apps_map, root_vertex) do
    {app, _, _} = app_tuple

    case Map.fetch(cached_apps_map, app) do
      {:ok, cached_vertex} ->
        current_vertex = Vertex.Application.from_app_tuple(app_tuple)

        if cached_vertex.version == current_vertex.version do
          []
        else
          [
            {:vertex, current_vertex},
            {:edge, root_vertex, current_vertex, :application}
          ]
        end

      :error ->
        app_vertex = Vertex.Application.from_app_tuple(app_tuple)

        [
          {:vertex, app_vertex},
          {:edge, root_vertex, app_vertex, :application}
        ]
    end
  end
end
