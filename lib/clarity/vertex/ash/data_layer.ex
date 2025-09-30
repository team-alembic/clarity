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
      @impl Clarity.Vertex
      def unique_id(%{data_layer: data_layer}), do: "data_layer:#{inspect(data_layer)}"

      @impl Clarity.Vertex
      def graph_id(%{data_layer: data_layer}), do: inspect(data_layer)

      @impl Clarity.Vertex
      def graph_group(_vertex), do: []

      @impl Clarity.Vertex
      def type_label(_vertex), do: inspect(Ash.DataLayer)

      @impl Clarity.Vertex
      def render_name(%{data_layer: data_layer}), do: inspect(data_layer)

      @impl Clarity.Vertex
      def dot_shape(_vertex), do: "cylinder"

      @impl Clarity.Vertex
      def markdown_overview(vertex) do
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

      @impl Clarity.Vertex
      def source_location(%{data_layer: module}) do
        SourceLocation.from_module(module)
      end
    end
  end
end
