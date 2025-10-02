with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Vertex.Ash.Resource do
    @moduledoc """
    Vertex implementation for Ash resources.
    """

    alias Ash.Resource.Info
    alias Clarity.SourceLocation

    @type t() :: %__MODULE__{
            resource: Ash.Resource.t()
          }
    @enforce_keys [:resource]
    defstruct [:resource]

    defimpl Clarity.Vertex do
      alias Clarity.Vertex.Util

      @impl Clarity.Vertex
      def id(%@for{resource: resource}), do: Util.id(@for, [resource])

      @impl Clarity.Vertex
      def type_label(_vertex), do: inspect(Ash.Resource)

      @impl Clarity.Vertex
      def name(%@for{resource: resource}), do: inspect(resource)
    end

    defimpl Clarity.Vertex.GraphGroupProvider do
      @impl Clarity.Vertex.GraphGroupProvider
      def graph_group(%@for{resource: resource}), do: [inspect(resource)]
    end

    defimpl Clarity.Vertex.GraphShapeProvider do
      @impl Clarity.Vertex.GraphShapeProvider
      def shape(_vertex), do: "component"
    end

    defimpl Clarity.Vertex.ModuleProvider do
      @impl Clarity.Vertex.ModuleProvider
      def module(%@for{resource: resource}), do: resource
    end

    defimpl Clarity.Vertex.SourceLocationProvider do
      @impl Clarity.Vertex.SourceLocationProvider
      def source_location(%@for{resource: module}) do
        SourceLocation.from_module(module)
      end
    end

    defimpl Clarity.Vertex.TooltipProvider do
      @impl Clarity.Vertex.TooltipProvider
      def tooltip(vertex) do
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
    end
  end
end
