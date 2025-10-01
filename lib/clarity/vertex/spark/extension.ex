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
      @impl Clarity.Vertex
      def unique_id(%{extension: extension}), do: "spark_extension:#{inspect(extension)}"

      @impl Clarity.Vertex
      def graph_id(%{extension: extension}), do: inspect(extension)

      @impl Clarity.Vertex
      def graph_group(_vertex), do: []

      @impl Clarity.Vertex
      def type_label(_vertex), do: "Spark Extension"

      @impl Clarity.Vertex
      def render_name(%{extension: extension}), do: inspect(extension)

      @impl Clarity.Vertex
      def dot_shape(_vertex), do: "component"

      @impl Clarity.Vertex
      def markdown_overview(vertex) do
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

      @impl Clarity.Vertex
      def source_location(%{extension: module}) do
        SourceLocation.from_module(module)
      end
    end
  end
end
