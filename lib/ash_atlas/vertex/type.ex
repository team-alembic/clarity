defmodule AshAtlas.Vertex.Type do
  @moduledoc false
  @type t() :: %__MODULE__{
          type: Ash.Type.t()
        }
  @enforce_keys [:type]
  defstruct [:type]

  defimpl AshAtlas.Vertex do
    @impl AshAtlas.Vertex
    def unique_id(%{type: type}), do: "type:#{inspect(type)}"

    @impl AshAtlas.Vertex
    def graph_id(%{type: type}), do: inspect(type)

    @impl AshAtlas.Vertex
    def graph_group(_vertex), do: []

    @impl AshAtlas.Vertex
    def type_label(_vertex), do: inspect(Ash.Type)

    @impl AshAtlas.Vertex
    def render_name(%{type: type}), do: inspect(type)

    @impl AshAtlas.Vertex
    def dot_shape(_vertex), do: "plain"

    @impl AshAtlas.Vertex
    def markdown_overview(vertex) do
      [
        "`",
        inspect(vertex.type),
        "`\n\n",
        case Code.fetch_docs(vertex.type) do
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
