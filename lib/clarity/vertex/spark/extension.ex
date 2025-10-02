with {:module, Spark} <- Code.ensure_loaded(Spark) do
  defmodule Clarity.Vertex.Spark.Extension do
    @moduledoc """
    Vertex implementation for Spark DSL Extensions.
    """

    alias Clarity.SourceLocation

    @type t() :: %__MODULE__{
            extension: module()
          }
    @enforce_keys [:extension]
    defstruct [:extension]

    defimpl Clarity.Vertex do
      alias Clarity.Vertex.Util

      @impl Clarity.Vertex
      def id(%@for{extension: extension}), do: Util.id(@for, [extension])

      @impl Clarity.Vertex
      def type_label(_vertex), do: "Spark Extension"

      @impl Clarity.Vertex
      def name(%@for{extension: extension}), do: inspect(extension)
    end

    defimpl Clarity.Vertex.GraphShapeProvider do
      @impl Clarity.Vertex.GraphShapeProvider
      def shape(_vertex), do: "component"
    end

    defimpl Clarity.Vertex.ModuleProvider do
      @impl Clarity.Vertex.ModuleProvider
      def module(%@for{extension: extension}), do: extension
    end

    defimpl Clarity.Vertex.SourceLocationProvider do
      @impl Clarity.Vertex.SourceLocationProvider
      def source_location(%@for{extension: module}) do
        SourceLocation.from_module(module)
      end
    end

    defimpl Clarity.Vertex.TooltipProvider do
      @impl Clarity.Vertex.TooltipProvider
      def tooltip(vertex) do
        [
          "`",
          inspect(vertex.extension),
          "`\n\n",
          case Code.fetch_docs(vertex.extension) do
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
