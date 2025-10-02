defmodule Clarity.Vertex.Module do
  @moduledoc """
  Vertex implementation for Elixir modules.
  """

  alias Clarity.SourceLocation

  @type t() :: %__MODULE__{
          module: module(),
          version: :unknown | integer(),
          behaviour?: boolean()
        }
  @enforce_keys [:module]
  defstruct [:module, version: :unknown, behaviour?: false]

  defimpl Clarity.Vertex do
    alias Clarity.Vertex.Util

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
        case Code.fetch_docs(module) do
          {:docs_v1, _annotation, _beam_language, "text/markdown", %{"en" => moduledoc},
           _metadata, _docs} ->
            ["\n\n", moduledoc]

          _ ->
            []
        end
      ]
    end
  end
end
