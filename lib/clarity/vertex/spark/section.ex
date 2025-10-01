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
      alias Spark.Dsl.Extension

      @impl Clarity.Vertex
      def unique_id(%{module: module, path: path}) do
        "spark_section:#{inspect(module)}:#{inspect(path)}"
      end

      @impl Clarity.Vertex
      def graph_id(%{module: module, path: path}) do
        "#{inspect(module)}.#{Enum.join(path, ".")}"
      end

      @impl Clarity.Vertex
      def graph_group(_vertex), do: []

      @impl Clarity.Vertex
      def type_label(_vertex), do: "Spark Section"

      @impl Clarity.Vertex
      def render_name(%{path: path}), do: Enum.join(path, " > ")

      @impl Clarity.Vertex
      def dot_shape(_vertex), do: "note"

      @impl Clarity.Vertex
      def markdown_overview(%{module: module, path: path}) do
        [
          "**Module:** `",
          inspect(module),
          "`\n\n",
          "**Section Path:** `",
          inspect(path),
          "`"
        ]
      end

      @impl Clarity.Vertex
      def source_location(%{module: module, path: path}) do
        case Extension.get_section_anno(module, path) do
          nil -> SourceLocation.from_module(module)
          anno -> SourceLocation.from_module_anno(module, anno)
        end
      end
    end
  end
end
