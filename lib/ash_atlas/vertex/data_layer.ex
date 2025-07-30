defmodule AshAtlas.Vertex.DataLayer do
  @moduledoc false
  @type t() :: %__MODULE__{
          data_layer: Ash.DataLayer.t()
        }
  @enforce_keys [:data_layer]
  defstruct [:data_layer]

  defimpl AshAtlas.Vertex do
    @impl AshAtlas.Vertex
    def unique_id(%{data_layer: data_layer}), do: "data_layer:#{inspect(data_layer)}"

    @impl AshAtlas.Vertex
    def graph_id(%{data_layer: data_layer}), do: inspect(data_layer)

    @impl AshAtlas.Vertex
    def graph_group(_vertex), do: []

    @impl AshAtlas.Vertex
    def type_label(_vertex), do: inspect(Ash.DataLayer)

    @impl AshAtlas.Vertex
    def render_name(%{data_layer: data_layer}), do: inspect(data_layer)

    @impl AshAtlas.Vertex
    def dot_shape(_vertex), do: "cylinder"

    @impl AshAtlas.Vertex
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
  end
end
