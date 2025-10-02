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
      alias Clarity.Vertex.Util

      @impl Clarity.Vertex
      def id(%@for{domain: domain}), do: Util.id(@for, [domain])

      @impl Clarity.Vertex
      def type_label(_vertex), do: inspect(Ash.Domain)

      @impl Clarity.Vertex
      def name(%@for{domain: domain}), do: inspect(domain)
    end

    defimpl Clarity.Vertex.GraphShapeProvider do
      @impl Clarity.Vertex.GraphShapeProvider
      def shape(_vertex), do: "folder"
    end

    defimpl Clarity.Vertex.ModuleProvider do
      @impl Clarity.Vertex.ModuleProvider
      def module(%@for{domain: domain}), do: domain
    end

    defimpl Clarity.Vertex.SourceLocationProvider do
      @impl Clarity.Vertex.SourceLocationProvider
      def source_location(%@for{domain: module}) do
        SourceLocation.from_module(module)
      end
    end

    defimpl Clarity.Vertex.TooltipProvider do
      @impl Clarity.Vertex.TooltipProvider
      def tooltip(vertex) do
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
end
