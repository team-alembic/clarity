defmodule Clarity.Introspector.Module do
  @moduledoc false

  @behaviour Clarity.Introspector

  alias Clarity.Vertex
  alias Clarity.Vertex.Module, as: ModuleVertex

  @impl Clarity.Introspector
  def source_vertex_types, do: [Clarity.Vertex.Application, ModuleVertex]

  @impl Clarity.Introspector
  def introspect_vertex(%Vertex.Application{app: app} = app_vertex, _graph) do
    app
    |> modules()
    |> Task.async_stream(&Code.ensure_loaded/1, ordered: false)
    |> Enum.filter(&match?({:ok, {:module, _}}, &1))
    |> Enum.flat_map(fn {:ok, {:module, module}} ->
      create_module_vertex_entries(module, app_vertex)
    end)
    |> then(&{:ok, &1})
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

    with {:ok, behaviour_edges} <- create_behaviour_edges(module_vertex, behaviours, lookup),
         {:ok, protocol_edges} <- create_protocol_edges(module_vertex, protocol_modules, lookup) do
      {:ok, behaviour_edges ++ protocol_edges}
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
    |> Task.async_stream(&Code.ensure_loaded/1, ordered: false)
    |> Enum.filter(&match?({:ok, {:module, _}}, &1))
    |> Enum.flat_map(fn {:ok, {:module, module}} ->
      create_module_vertex_entries(module, app_vertex)
    end)
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
      | Clarity.Introspector.moduledoc_content(module, module_vertex)
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

  @spec create_behaviour_edges(ModuleVertex.t(), [module()], %{module() => ModuleVertex.t()}) ::
          Clarity.Introspector.result()
  defp create_behaviour_edges(_module_vertex, [], _lookup), do: {:ok, []}

  defp create_behaviour_edges(module_vertex, behaviours, lookup) do
    Enum.reduce_while(behaviours, {:ok, []}, fn behaviour, {:ok, edges} ->
      case Map.fetch(lookup, behaviour) do
        {:ok, behaviour_vertex} ->
          {:cont, {:ok, [{:edge, module_vertex, behaviour_vertex, :behaviour} | edges]}}

        :error ->
          {:halt, {:error, :unmet_dependencies}}
      end
    end)
  end

  @spec create_protocol_edges(
          ModuleVertex.t(),
          {module(), module()} | nil,
          %{module() => ModuleVertex.t()}
        ) ::
          Clarity.Introspector.result()
  defp create_protocol_edges(_module_vertex, nil, _lookup), do: {:ok, []}

  defp create_protocol_edges(module_vertex, {protocol, for_module}, lookup) do
    with {:ok, protocol_vertex} <- Map.fetch(lookup, protocol),
         {:ok, for_vertex} <- Map.fetch(lookup, for_module) do
      {:ok,
       [
         {:edge, protocol_vertex, module_vertex, :protocol_implementation},
         {:edge, module_vertex, for_vertex, :protocol_subject}
       ]}
    else
      :error -> {:error, :unmet_dependencies}
    end
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
    graph
    |> Clarity.Graph.vertices(type: ModuleVertex, field_in: {:module, needed_modules})
    |> Map.new(&{&1.module, &1})
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
