defmodule Clarity.Introspector.Module do
  @moduledoc false

  @behaviour Clarity.Introspector

  alias Clarity.Vertex
  alias Clarity.Vertex.Module, as: ModuleVertex

  @impl Clarity.Introspector
  def source_vertex_types, do: [Clarity.Vertex.Application, ModuleVertex]

  @impl Clarity.Introspector
  def introspect_vertex(%Vertex.Application{app: app} = app_vertex, graph) do
    current_modules = app |> modules() |> load_modules()

    cached_modules = get_cached_modules(graph, app_vertex)

    current_modules_map =
      Map.new(current_modules, fn module ->
        {module, get_module_version(module)}
      end)

    cached_modules_map =
      Map.new(cached_modules, fn vertex ->
        {vertex.module, vertex.version}
      end)

    purge_entries =
      Enum.flat_map(cached_modules, fn cached_vertex ->
        purge_module_if_changed(cached_vertex, current_modules_map)
      end)

    add_entries =
      Enum.flat_map(current_modules, fn module ->
        add_module_entries(module, cached_modules_map, app_vertex)
      end)

    {:ok, purge_entries ++ add_entries}
  end

  @impl Clarity.Introspector
  def introspect_vertex(%ModuleVertex{module: module} = module_vertex, graph) do
    behaviours = get_behaviours(module)
    protocol_modules = module |> get_protocol_info() |> validate_and_load_protocol_modules()

    needed_modules =
      behaviours ++
        case protocol_modules do
          nil -> []
          {protocol, for_module} -> [protocol, for_module]
        end

    lookup = build_module_lookup(graph, needed_modules)

    case needed_modules |> Enum.reject(&Map.has_key?(lookup, &1)) |> Enum.uniq() do
      [] ->
        {:ok,
         behaviour_edges(module_vertex, behaviours, lookup) ++
           protocol_edges(module_vertex, protocol_modules, lookup)}

      missing ->
        {:error, {:unmet_dependencies, missing}}
    end
  end

  @doc """
  Creates introspection results for specific modules within an application.

  This is used for incremental introspection where only certain modules have changed.
  Instead of introspecting all modules in an application, this function creates vertices
  and edges for only the specified modules.
  """
  @spec introspect_modules(Vertex.Application.t(), [module()], Clarity.Graph.t()) ::
          [Clarity.Introspector.entry()]
  def introspect_modules(%Vertex.Application{} = app_vertex, modules, _graph) do
    modules
    |> load_modules()
    |> Enum.flat_map(&create_module_vertex_entries(&1, app_vertex))
  end

  # Loads the modules, returning those that loaded. The code server loads one
  # module at a time, but this reads them in parallel first.
  @spec load_modules([module()]) :: [module()]
  defp load_modules(modules) do
    case :code.ensure_modules_loaded(modules) do
      :ok ->
        modules

      {:error, failures} ->
        failed = MapSet.new(failures, &elem(&1, 0))
        Enum.reject(modules, &MapSet.member?(failed, &1))
    end
  end

  @spec get_cached_modules(Clarity.Graph.t(), Vertex.Application.t()) :: [ModuleVertex.t()]
  defp get_cached_modules(graph, app_vertex) do
    graph
    |> Clarity.Graph.out_neighbors(app_vertex)
    |> Enum.filter(&match?(%ModuleVertex{}, &1))
  end

  @spec purge_module_if_changed(ModuleVertex.t(), %{module() => :unknown | integer()}) ::
          [Clarity.Introspector.entry()]
  defp purge_module_if_changed(cached_vertex, current_modules_map) do
    case Map.fetch(current_modules_map, cached_vertex.module) do
      {:ok, current_version} ->
        if cached_vertex.version == current_version do
          []
        else
          [{:purge, cached_vertex}]
        end

      :error ->
        [{:purge, cached_vertex}]
    end
  end

  @spec add_module_entries(
          module(),
          %{module() => :unknown | integer()},
          Vertex.Application.t()
        ) :: [Clarity.Introspector.entry()]
  defp add_module_entries(module, cached_modules_map, app_vertex) do
    case Map.fetch(cached_modules_map, module) do
      {:ok, cached_version} ->
        current_version = get_module_version(module)

        if cached_version == current_version do
          []
        else
          create_module_vertex_entries(module, app_vertex)
        end

      :error ->
        create_module_vertex_entries(module, app_vertex)
    end
  end

  @spec create_module_vertex_entries(module(), Vertex.Application.t()) ::
          [Clarity.Introspector.entry()]
  defp create_module_vertex_entries(module, app_vertex) do
    module_vertex = %ModuleVertex{
      module: module,
      version: get_module_version(module),
      behaviour?: behaviour?(module)
    }

    [
      {:vertex, module_vertex},
      {:edge, app_vertex, module_vertex, :module}
    ]
  end

  @spec modules(app :: Application.app()) :: [module()]
  defp modules(app) do
    Application.spec(app, :modules) || []
  end

  @spec get_behaviours(module()) :: [module()]
  defp get_behaviours(module) do
    module.module_info(:attributes)[:behaviour]
    |> List.wrap()
    |> Enum.filter(&Clarity.Config.should_process_module?/1)
    |> Enum.map(&Code.ensure_loaded/1)
    |> Enum.filter(&match?({:module, _}, &1))
    |> Enum.map(fn {:module, behaviour} -> behaviour end)
    |> Enum.filter(&behaviour?/1)
  end

  @spec validate_and_load_protocol_modules({module(), module()} | nil) ::
          {module(), module()} | nil
  defp validate_and_load_protocol_modules(nil), do: nil

  defp validate_and_load_protocol_modules({protocol, for_module}) do
    with true <- Clarity.Config.should_process_module?(protocol),
         true <- Clarity.Config.should_process_module?(for_module),
         {:module, ^protocol} <- Code.ensure_loaded(protocol),
         {:module, ^for_module} <- Code.ensure_loaded(for_module) do
      {protocol, for_module}
    else
      _ -> nil
    end
  end

  @spec behaviour_edges(ModuleVertex.t(), [module()], %{module() => ModuleVertex.t()}) ::
          [Clarity.Introspector.entry()]
  defp behaviour_edges(module_vertex, behaviours, lookup) do
    for behaviour <- Enum.reverse(behaviours),
        do: {:edge, module_vertex, Map.fetch!(lookup, behaviour), :behaviour}
  end

  @spec protocol_edges(ModuleVertex.t(), {module(), module()} | nil, %{
          module() => ModuleVertex.t()
        }) :: [Clarity.Introspector.entry()]
  defp protocol_edges(_module_vertex, nil, _lookup), do: []

  defp protocol_edges(module_vertex, {protocol, for_module}, lookup) do
    [
      {:edge, Map.fetch!(lookup, protocol), module_vertex, :protocol_implementation},
      {:edge, module_vertex, Map.fetch!(lookup, for_module), :protocol_subject}
    ]
  end

  @spec get_module_version(module :: module()) :: :unknown | integer()
  defp get_module_version(module), do: ModuleVertex.version(module)

  @spec behaviour?(module :: module()) :: boolean()
  defp behaviour?(module) do
    case Code.ensure_compiled(module) do
      {:module, ^module} ->
        function_exported?(module, :behaviour_info, 1)

      _ ->
        false
    end
  end

  @spec build_module_lookup(Clarity.Graph.t(), [module()]) :: %{module() => ModuleVertex.t()}
  defp build_module_lookup(graph, needed_modules) do
    for module <- needed_modules,
        vertex = ModuleVertex.lookup(graph, module),
        into: %{},
        do: {module, vertex}
  end

  @spec get_protocol_info(module :: module()) :: {module(), module()} | nil
  defp get_protocol_info(module) do
    case module.module_info(:attributes)[:__impl__] do
      nil ->
        nil

      impl_info ->
        protocol = Keyword.get(impl_info, :protocol)
        for_module = Keyword.get(impl_info, :for)

        if protocol && for_module do
          {protocol, for_module}
        end
    end
  end
end
