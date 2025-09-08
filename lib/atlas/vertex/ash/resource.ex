with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Atlas.Vertex.Ash.Resource do
    @moduledoc false
    @type t() :: %__MODULE__{
            resource: Ash.Resource.t()
          }
    @enforce_keys [:resource]
    defstruct [:resource]

    defimpl Atlas.Vertex do
      @impl Atlas.Vertex
      def unique_id(%{resource: resource}), do: "resource:#{inspect(resource)}"

      @impl Atlas.Vertex
      def graph_id(%{resource: resource}), do: inspect(resource)

      @impl Atlas.Vertex
      def graph_group(%{resource: resource}), do: [inspect(resource)]

      @impl Atlas.Vertex
      def type_label(_vertex), do: inspect(Ash.Resource)

      @impl Atlas.Vertex
      def render_name(%{resource: resource}), do: inspect(resource)

      @impl Atlas.Vertex
      def dot_shape(_vertex), do: "component"

      @impl Atlas.Vertex
      def markdown_overview(vertex) do
        [
          "`",
          inspect(vertex.resource),
          "`\n\n",
          "Domain: `",
          inspect(Ash.Resource.Info.domain(vertex.resource)),
          "`\n\n",
          case Code.fetch_docs(vertex.resource) do
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
