defmodule Clarity.Vertex.Module do
  @moduledoc """
  Vertex implementation for Elixir modules.
  """

  alias Clarity.Graph
  alias Clarity.SourceLocation
  alias Clarity.Vertex.HintProvider
  alias Clarity.Vertex.Util

  @type t() :: %__MODULE__{
          module: module(),
          version: :unknown | integer(),
          behaviour?: boolean()
        }
  @enforce_keys [:module]
  defstruct [:module, version: :unknown, behaviour?: false]

  @doc """
  Returns the vertex in `graph` for `module` as it is loaded now, or `nil`.

  A vertex's id includes its module's version, so this looks it up directly
  rather than searching the graph.
  """
  @spec lookup(Graph.t(), module()) :: t() | nil
  def lookup(graph, module) do
    if Code.ensure_loaded?(module),
      do: Graph.get_vertex(graph, Util.id(__MODULE__, [module, version(module)]))
  end

  @doc """
  Returns the version of a loaded `module` (its `vsn` attribute).
  """
  @spec version(module()) :: :unknown | integer()
  def version(module) do
    case module.module_info(:attributes)[:vsn] do
      [version] -> version
      _none -> :unknown
    end
  end

  defimpl Clarity.Vertex do
    @impl Clarity.Vertex
    def id(%@for{module: module, version: version}) do
      Util.id(@for, [module, version])
    end

    @impl Clarity.Vertex
    def type_label(_vertex), do: inspect(Module)

    @impl Clarity.Vertex
    def name(%@for{module: module}), do: inspect(module)
  end

  defimpl Clarity.Vertex.GraphShapeProvider do
    @impl Clarity.Vertex.GraphShapeProvider
    def shape(_vertex), do: "box"
  end

  defimpl Clarity.Vertex.ModuleProvider do
    @impl Clarity.Vertex.ModuleProvider
    def module(%{module: module}), do: module
  end

  defimpl Clarity.Vertex.SourceLocationProvider do
    @impl Clarity.Vertex.SourceLocationProvider
    def source_location(%{module: module}) do
      SourceLocation.from_module(module)
    end
  end

  defimpl Clarity.Vertex.TooltipProvider do
    @impl Clarity.Vertex.TooltipProvider
    def tooltip(%{module: module}) do
      [
        "`",
        inspect(module),
        "`",
        case Clarity.Docs.moduledoc(module) do
          nil -> []
          moduledoc -> ["\n\n", moduledoc]
        end
      ]
    end
  end

  defimpl Clarity.Vertex.HintProvider do
    @impl HintProvider
    def icon(_vertex), do: :module

    @impl HintProvider
    def badges(%@for{behaviour?: behaviour?}), do: if(behaviour?, do: ["behaviour"], else: [])

    @impl HintProvider
    def facts(_vertex), do: []
  end
end
