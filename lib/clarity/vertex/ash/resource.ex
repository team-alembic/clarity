with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Vertex.Ash.Resource do
    @moduledoc false

    alias Ash.Resource.Info

    @type t() :: %__MODULE__{
            resource: Ash.Resource.t()
          }
    @enforce_keys [:resource]
    defstruct [:resource]

    defimpl Clarity.Vertex do
      @impl Clarity.Vertex
      def unique_id(%{resource: resource}), do: "resource:#{inspect(resource)}"

      @impl Clarity.Vertex
      def graph_id(%{resource: resource}), do: inspect(resource)

      @impl Clarity.Vertex
      def graph_group(%{resource: resource}), do: [inspect(resource)]

      @impl Clarity.Vertex
      def type_label(_vertex), do: inspect(Ash.Resource)

      @impl Clarity.Vertex
      def render_name(%{resource: resource}), do: inspect(resource)

      @impl Clarity.Vertex
      def dot_shape(_vertex), do: "component"

      @impl Clarity.Vertex
      def markdown_overview(vertex) do
        [
          "`",
          inspect(vertex.resource),
          "`\n\n",
          "Domain: `",
          inspect(Info.domain(vertex.resource)),
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

      @impl Clarity.Vertex
      # TODO: Add anno once ash supports it
      def source_anno(_vertex), do: nil
    end
  end
end
