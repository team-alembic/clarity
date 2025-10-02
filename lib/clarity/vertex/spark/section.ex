with {:module, Spark} <- Code.ensure_loaded(Spark) do
  defmodule Clarity.Vertex.Spark.Section do
    @moduledoc """
    Vertex implementation for Spark DSL sections.

    Represents a configured section in a Spark DSL implementation.
    For example, the `[:attributes]` section in an Ash Resource.
    """

    alias Clarity.SourceLocation

    @type t() :: %__MODULE__{
            module: module(),
            path: [atom()]
          }
    @enforce_keys [:module, :path]
    defstruct [:module, :path]

    defimpl Clarity.Vertex do
      alias Clarity.Vertex.Util

      @impl Clarity.Vertex
      def id(%@for{module: module, path: path}) do
        Util.id(@for, [module, inspect(path)])
      end

      @impl Clarity.Vertex
      def type_label(_vertex), do: "Spark Section"

      @impl Clarity.Vertex
      def name(%@for{path: path}), do: Enum.join(path, " > ")
    end

    defimpl Clarity.Vertex.GraphShapeProvider do
      @impl Clarity.Vertex.GraphShapeProvider
      def shape(_vertex), do: "note"
    end

    defimpl Clarity.Vertex.SourceLocationProvider do
      alias Spark.Dsl.Extension

      @impl Clarity.Vertex.SourceLocationProvider
      def source_location(%@for{module: module, path: path}) do
        case Extension.get_section_anno(module, path) do
          nil -> SourceLocation.from_module(module)
          anno -> SourceLocation.from_module_anno(module, anno)
        end
      end
    end

    defimpl Clarity.Vertex.TooltipProvider do
      @impl Clarity.Vertex.TooltipProvider
      def tooltip(%@for{module: module, path: path}) do
        [
          "**Module:** `",
          inspect(module),
          "`\n\n",
          "**Section Path:** `",
          inspect(path),
          "`"
        ]
      end
    end
  end
end
