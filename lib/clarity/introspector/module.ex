defmodule Clarity.Introspector.Module do
  @moduledoc false

  @behaviour Clarity.Introspector

  alias Clarity.Vertex
  alias Clarity.Vertex.Module, as: ModuleVertex

  @impl Clarity.Introspector
  def source_vertex_types, do: [Clarity.Vertex.Application]

  @impl Clarity.Introspector
  def introspect_vertex(%Vertex.Application{app: app} = app_vertex, _graph) do
    app
    |> modules()
    |> Enum.flat_map(fn module ->
      version = get_module_version(module)
      module_vertex = %ModuleVertex{module: module, version: version}

      [
        {:vertex, module_vertex},
        {:edge, app_vertex, module_vertex, :module}
        | Clarity.Introspector.moduledoc_content(module, module_vertex)
      ]
    end)
  end

  def introspect_vertex(_vertex, _graph), do: []

  @doc """
  Creates introspection results for specific modules within an application.

  This is used for incremental introspection where only certain modules have changed.
  Instead of introspecting all modules in an application, this function creates vertices
  and edges for only the specified modules.

  ## Parameters

  - `app_vertex` - The Application vertex that owns these modules
  - `modules` - List of module names to create vertices for
  - `_graph` - The current graph (not used but follows introspector pattern)

  ## Returns

  List of `{:vertex, module_vertex}` and `{:edge, app_vertex, module_vertex, :module}` tuples.
  """
  @spec introspect_modules(Vertex.Application.t(), [module()], Clarity.Graph.t()) ::
          Clarity.Introspector.results()
  def introspect_modules(%Vertex.Application{} = app_vertex, modules, _graph) do
    Enum.flat_map(modules, fn module ->
      version = get_module_version(module)
      module_vertex = %ModuleVertex{module: module, version: version}

      [
        {:vertex, module_vertex},
        {:edge, app_vertex, module_vertex, :module}
        | Clarity.Introspector.moduledoc_content(module, module_vertex)
      ]
    end)
  end

  @spec modules(app :: Application.app()) :: [module()]
  defp modules(app) do
    Application.spec(app, :modules) || []
  end

  @spec get_module_version(module :: module()) :: :unknown | String.t()
  defp get_module_version(module) do
    case module.module_info(:attributes)[:vsn] do
      nil -> :unknown
      [version] when is_list(version) -> List.to_string(version)
      version when is_list(version) -> List.to_string(version)
      version -> to_string(version)
    end
  rescue
    _ -> :unknown
  end
end
