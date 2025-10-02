defmodule Clarity.Vertex.Phoenix.Endpoint do
  @moduledoc """
  Vertex implementation for Phoenix endpoints.
  """

  alias Clarity.SourceLocation

  @type t() :: %__MODULE__{endpoint: module()}
  @enforce_keys [:endpoint]
  defstruct [:endpoint]

  defimpl Clarity.Vertex do
    alias Clarity.Vertex.Util

    @impl Clarity.Vertex
    def id(%@for{endpoint: module}), do: Util.id(@for, [module])

    @impl Clarity.Vertex
    def type_label(_vertex), do: "Clarity.Vertex.Phoenix.Endpoint"

    @impl Clarity.Vertex
    def name(%@for{endpoint: module}), do: inspect(module)
  end

  defimpl Clarity.Vertex.GraphShapeProvider do
    @impl Clarity.Vertex.GraphShapeProvider
    def shape(_vertex), do: "foo"
  end

  defimpl Clarity.Vertex.ModuleProvider do
    @impl Clarity.Vertex.ModuleProvider
    def module(%@for{endpoint: endpoint}), do: endpoint
  end

  defimpl Clarity.Vertex.SourceLocationProvider do
    @impl Clarity.Vertex.SourceLocationProvider
    def source_location(%@for{endpoint: module}) do
      SourceLocation.from_module(module)
    end
  end

  defimpl Clarity.Vertex.TooltipProvider do
    @impl Clarity.Vertex.TooltipProvider
    def tooltip(%@for{endpoint: module}),
      do: ["`", inspect(module), "`\n\n", "URL: ", module.url()]
  end
end
