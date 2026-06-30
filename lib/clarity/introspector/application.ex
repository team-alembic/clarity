defmodule Clarity.Introspector.Application do
  @moduledoc false

  @behaviour Clarity.Introspector

  alias Clarity.Config
  alias Clarity.Graph
  alias Clarity.Vertex

  @impl Clarity.Introspector
  def source_vertex_types, do: [Vertex.Root]

  @impl Clarity.Introspector
  def introspect_vertex(%Vertex.Root{} = root_vertex, graph) do
    current_apps = Config.filtered_applications()
    cached_apps = get_cached_applications(graph)

    current_apps_map = Map.new(current_apps, fn {app, _, _} = tuple -> {app, tuple} end)
    cached_apps_map = Map.new(cached_apps, fn vertex -> {vertex.app, vertex} end)

    purge_entries = Enum.flat_map(cached_apps, &purge_app_if_changed(&1, current_apps_map))
    vertex_entries = Enum.flat_map(current_apps, &vertex_entry(&1, cached_apps_map))
    edge_entries = structural_edges(root_vertex, current_apps)

    {:ok, purge_entries ++ vertex_entries ++ edge_entries}
  end

  @spec get_cached_applications(Graph.t()) :: [Vertex.Application.t()]
  defp get_cached_applications(graph) do
    Graph.vertices(graph, {:==, :vertex_type, Vertex.Application})
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

  @spec vertex_entry(
          {Application.app(), charlist(), charlist()},
          %{Application.app() => Vertex.Application.t()}
        ) :: [Clarity.Introspector.entry()]
  defp vertex_entry(app_tuple, cached_apps_map) do
    {app, _, _} = app_tuple

    case Map.fetch(cached_apps_map, app) do
      {:ok, cached_vertex} ->
        current_vertex = Vertex.Application.from_app_tuple(app_tuple)

        if cached_vertex.version == current_vertex.version do
          []
        else
          [{:vertex, current_vertex}]
        end

      :error ->
        [{:vertex, Vertex.Application.from_app_tuple(app_tuple)}]
    end
  end

  # Emit application/dependency edges in BFS order from the dependency forest's
  # roots (apps nothing else depends on). The nav tree keeps the shortest path
  # from the root, so receiving edges parent-before-child nests transitive
  # dependencies under the application that pulls them in, rather than listing
  # every app flat under the root.
  @spec structural_edges(Vertex.Root.t(), [{Application.app(), charlist(), charlist()}]) ::
          [Clarity.Introspector.entry()]
  defp structural_edges(root_vertex, current_apps) do
    app_names = Enum.map(current_apps, fn {app, _, _} -> app end)
    current_set = MapSet.new(app_names)

    vertices =
      Map.new(current_apps, fn {app, _, _} = tuple ->
        {app, Vertex.Application.from_app_tuple(tuple)}
      end)

    deps_of = Map.new(app_names, fn app -> {app, app_dependencies(app, current_set)} end)
    depended = deps_of |> Map.values() |> Enum.concat() |> MapSet.new()
    roots = Enum.reject(app_names, &MapSet.member?(depended, &1))

    initial = Enum.map(roots, &{:edge, root_vertex, Map.fetch!(vertices, &1), :application})
    bfs(roots, MapSet.new(roots), app_names, deps_of, vertices, root_vertex, initial)
  end

  @spec app_dependencies(Application.app(), MapSet.t(Application.app())) :: [Application.app()]
  defp app_dependencies(app, current_set) do
    spec = Application.spec(app) || []

    [spec[:applications], spec[:included_applications], spec[:optional_applications]]
    |> Enum.flat_map(&List.wrap/1)
    |> Enum.filter(&MapSet.member?(current_set, &1))
    |> Enum.uniq()
  end

  @spec bfs(
          [Application.app()],
          MapSet.t(Application.app()),
          [Application.app()],
          %{Application.app() => [Application.app()]},
          %{Application.app() => Vertex.Application.t()},
          Vertex.Root.t(),
          [Clarity.Introspector.entry()]
        ) :: [Clarity.Introspector.entry()]
  defp bfs([], visited, app_names, deps_of, vertices, root_vertex, acc) do
    case Enum.find(app_names, &(not MapSet.member?(visited, &1))) do
      nil ->
        acc

      leftover ->
        # Cycle with no external entry point: seed it as an additional root.
        acc = acc ++ [{:edge, root_vertex, Map.fetch!(vertices, leftover), :application}]

        bfs(
          [leftover],
          MapSet.put(visited, leftover),
          app_names,
          deps_of,
          vertices,
          root_vertex,
          acc
        )
    end
  end

  defp bfs([app | rest], visited, app_names, deps_of, vertices, root_vertex, acc) do
    deps = Map.fetch!(deps_of, app)

    acc =
      acc ++
        Enum.map(deps, fn dep ->
          {:edge, Map.fetch!(vertices, app), Map.fetch!(vertices, dep), :dependency}
        end)

    new_deps = Enum.reject(deps, &MapSet.member?(visited, &1))
    visited = Enum.reduce(new_deps, visited, &MapSet.put(&2, &1))
    bfs(rest ++ new_deps, visited, app_names, deps_of, vertices, root_vertex, acc)
  end
end
