with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Vertex.Ash.Domain do
    @moduledoc """
    Vertex implementation for Ash domains.
    """

    alias Clarity.SourceLocation

    @type t() :: %__MODULE__{
            domain: Ash.Domain.t()
          }
    @enforce_keys [:domain]
    defstruct [:domain]

    defimpl Clarity.Vertex do
      @impl Clarity.Vertex
      def unique_id(%{domain: domain}), do: "domain:#{inspect(domain)}"

      @impl Clarity.Vertex
      def graph_id(%{domain: domain}), do: inspect(domain)

      @impl Clarity.Vertex
      def graph_group(_vertex), do: []

      @impl Clarity.Vertex
      def type_label(_vertex), do: inspect(Ash.Domain)

      @impl Clarity.Vertex
      def render_name(%{domain: domain}), do: inspect(domain)

      @impl Clarity.Vertex
      def dot_shape(_vertex), do: "folder"

      @impl Clarity.Vertex
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

      @impl Clarity.Vertex
      def source_location(%{domain: module}) do
        SourceLocation.from_module(module)
      end
    end
  end
end
