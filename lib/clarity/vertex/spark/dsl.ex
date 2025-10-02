with {:module, Spark} <- Code.ensure_loaded(Spark) do
  defmodule Clarity.Vertex.Spark.Dsl do
    @moduledoc """
    Vertex implementation for Spark DSL modules.
    """

    alias Clarity.SourceLocation

    @type t() :: %__MODULE__{
            dsl: module()
          }
    @enforce_keys [:dsl]
    defstruct [:dsl]

    defimpl Clarity.Vertex do
      alias Clarity.Vertex.Util

      @impl Clarity.Vertex
      def id(%@for{dsl: dsl}), do: Util.id(@for, [dsl])

      @impl Clarity.Vertex
      def type_label(_vertex), do: "Spark DSL"

      @impl Clarity.Vertex
      def name(%@for{dsl: dsl}), do: inspect(dsl)
    end

    defimpl Clarity.Vertex.GraphShapeProvider do
      @impl Clarity.Vertex.GraphShapeProvider
      def shape(_vertex), do: "hexagon"
    end

    defimpl Clarity.Vertex.ModuleProvider do
      @impl Clarity.Vertex.ModuleProvider
      def module(%@for{dsl: dsl}), do: dsl
    end

    defimpl Clarity.Vertex.SourceLocationProvider do
      @impl Clarity.Vertex.SourceLocationProvider
      def source_location(%@for{dsl: module}) do
        SourceLocation.from_module(module)
      end
    end

    defimpl Clarity.Vertex.TooltipProvider do
      @impl Clarity.Vertex.TooltipProvider
      def tooltip(vertex) do
        [
          "`",
          inspect(vertex.dsl),
          "`\n\n",
          case Code.fetch_docs(vertex.dsl) do
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
