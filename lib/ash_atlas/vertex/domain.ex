defmodule AshAtlas.Vertex.Domain do
  @moduledoc false
  @type t() :: %__MODULE__{
          domain: Ash.Domain.t()
        }
  @enforce_keys [:domain]
  defstruct [:domain]

  defimpl AshAtlas.Vertex do
    @impl AshAtlas.Vertex
    def unique_id(%{domain: domain}), do: "domain:#{inspect(domain)}"

    @impl AshAtlas.Vertex
    def graph_id(%{domain: domain}), do: inspect(domain)

    @impl AshAtlas.Vertex
    def graph_group(_vertex), do: []

    @impl AshAtlas.Vertex
    def type_label(_vertex), do: inspect(Ash.Domain)

    @impl AshAtlas.Vertex
    def render_name(%{domain: domain}), do: inspect(domain)

    @impl AshAtlas.Vertex
    def dot_shape(_vertex), do: "folder"

    @impl AshAtlas.Vertex
    def markdown_overview(vertex) do
      [
        "`",
        inspect(vertex.domain),
        "`\n\n",
        case Code.fetch_docs(vertex.domain) do
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
