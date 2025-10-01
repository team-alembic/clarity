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
      @impl Clarity.Vertex
      def unique_id(%{dsl: dsl}), do: "spark_dsl:#{inspect(dsl)}"

      @impl Clarity.Vertex
      def graph_id(%{dsl: dsl}), do: inspect(dsl)

      @impl Clarity.Vertex
      def graph_group(_vertex), do: []

      @impl Clarity.Vertex
      def type_label(_vertex), do: "Spark DSL"

      @impl Clarity.Vertex
      def render_name(%{dsl: dsl}), do: inspect(dsl)

      @impl Clarity.Vertex
      def dot_shape(_vertex), do: "hexagon"

      @impl Clarity.Vertex
      def markdown_overview(vertex) do
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

      @impl Clarity.Vertex
      def source_location(%{dsl: module}) do
        SourceLocation.from_module(module)
      end
    end
  end
end
