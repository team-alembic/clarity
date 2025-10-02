with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Vertex.Ash.DataLayer do
    @moduledoc """
    Vertex implementation for Ash data layers.
    """

    alias Clarity.SourceLocation

    @type t() :: %__MODULE__{
            data_layer: Ash.DataLayer.t()
          }
    @enforce_keys [:data_layer]
    defstruct [:data_layer]

    defimpl Clarity.Vertex do
      alias Clarity.Vertex.Util

      @impl Clarity.Vertex
      def id(%@for{data_layer: data_layer}), do: Util.id(@for, [data_layer])

      @impl Clarity.Vertex
      def type_label(_vertex), do: inspect(Ash.DataLayer)

      @impl Clarity.Vertex
      def name(%@for{data_layer: data_layer}), do: inspect(data_layer)
    end

    defimpl Clarity.Vertex.GraphShapeProvider do
      @impl Clarity.Vertex.GraphShapeProvider
      def shape(_vertex), do: "cylinder"
    end

    defimpl Clarity.Vertex.ModuleProvider do
      @impl Clarity.Vertex.ModuleProvider
      def module(%@for{data_layer: data_layer}), do: data_layer
    end

    defimpl Clarity.Vertex.SourceLocationProvider do
      @impl Clarity.Vertex.SourceLocationProvider
      def source_location(%@for{data_layer: module}) do
        SourceLocation.from_module(module)
      end
    end

    defimpl Clarity.Vertex.TooltipProvider do
      @impl Clarity.Vertex.TooltipProvider
      def tooltip(vertex) do
        [
          "`",
          inspect(vertex.data_layer),
          "`\n\n",
          case Code.fetch_docs(vertex.data_layer) do
            {:docs_v1, _annotation, _beam_language, "text/markdown", %{"en" => moduledoc},
             _metadata, _docs} ->
              moduledoc

            _ ->
              []
          end
        ]
      end
    end
  end
end
