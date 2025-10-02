defmodule Clarity.Vertex.Phoenix.Router do
  @moduledoc """
  Vertex implementation for Phoenix routers.
  """

  alias Clarity.SourceLocation

  @type t() :: %__MODULE__{router: module()}
  @enforce_keys [:router]
  defstruct [:router]

  defimpl Clarity.Vertex do
    alias Clarity.Vertex.Util

    @impl Clarity.Vertex
    def id(%@for{router: module}), do: Util.id(@for, [module])

    @impl Clarity.Vertex
    def type_label(_vertex), do: "Clarity.Vertex.Phoenix.Router"

    @impl Clarity.Vertex
    def name(%@for{router: module}), do: inspect(module)
  end

  defimpl Clarity.Vertex.GraphShapeProvider do
    @impl Clarity.Vertex.GraphShapeProvider
    def shape(_vertex), do: "foo"
  end

  defimpl Clarity.Vertex.ModuleProvider do
    @impl Clarity.Vertex.ModuleProvider
    def module(%@for{router: router}), do: router
  end

  defimpl Clarity.Vertex.SourceLocationProvider do
    @impl Clarity.Vertex.SourceLocationProvider
    def source_location(%@for{router: module}) do
      SourceLocation.from_module(module)
    end
  end
end
