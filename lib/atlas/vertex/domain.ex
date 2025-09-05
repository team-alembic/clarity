defmodule Atlas.Vertex.Domain do
  @moduledoc false
  @type t() :: %__MODULE__{
          domain: Ash.Domain.t()
        }
  @enforce_keys [:domain]
  defstruct [:domain]

  defimpl Atlas.Vertex do
    @impl Atlas.Vertex
    def unique_id(%{domain: domain}), do: "domain:#{inspect(domain)}"

    @impl Atlas.Vertex
    def graph_id(%{domain: domain}), do: inspect(domain)

    @impl Atlas.Vertex
    def graph_group(_vertex), do: []

    @impl Atlas.Vertex
    def type_label(_vertex), do: inspect(Ash.Domain)

    @impl Atlas.Vertex
    def render_name(%{domain: domain}), do: inspect(domain)

    @impl Atlas.Vertex
    def dot_shape(_vertex), do: "folder"

    @impl Atlas.Vertex
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
