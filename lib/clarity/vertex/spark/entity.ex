with {:module, Spark} <- Code.ensure_loaded(Spark) do
  defmodule Clarity.Vertex.Spark.Entity do
    @moduledoc """
    Vertex implementation for Spark DSL entities.

    Represents a configured entity within a Spark DSL section.
    For example, an individual attribute in the `[:attributes]` section of an Ash Resource.
    """

    alias Clarity.SourceLocation

    @type t() :: %__MODULE__{
            module: module(),
            path: [atom()],
            entity: struct()
          }
    @enforce_keys [:module, :path, :entity]
    defstruct [:module, :path, :entity]

    defimpl Clarity.Vertex do
      alias Spark.Dsl.Entity, as: SparkEntity

      @impl Clarity.Vertex
      def unique_id(%{module: module, path: path, entity: entity}) do
        entity_name = Map.get(entity, :name, inspect(entity))
        "spark_entity:#{inspect(module)}:#{inspect(path)}:#{inspect(entity_name)}"
      end

      @impl Clarity.Vertex
      def graph_id(%{module: module, path: path, entity: entity}) do
        entity_name = Map.get(entity, :name, inspect(entity))
        "#{inspect(module)}.#{Enum.join(path, ".")}.#{entity_name}"
      end

      @impl Clarity.Vertex
      def graph_group(_vertex), do: []

      @impl Clarity.Vertex
      def type_label(_vertex), do: "Spark Entity"

      @impl Clarity.Vertex
      def render_name(%{entity: entity}) do
        entity |> Map.get(:name, inspect(entity)) |> to_string()
      end

      @impl Clarity.Vertex
      def dot_shape(_vertex), do: "box"

      @impl Clarity.Vertex
      def markdown_overview(%{module: module, path: path, entity: entity}) do
        entity_name = Map.get(entity, :name, inspect(entity))

        [
          "**Module:** `",
          inspect(module),
          "`\n\n",
          "**Section Path:** `",
          inspect(path),
          "`\n\n",
          "**Entity:** `",
          to_string(entity_name),
          "`"
        ]
      end

      @impl Clarity.Vertex
      def source_location(%{module: module, entity: entity}) do
        case SparkEntity.anno(entity) do
          nil -> SourceLocation.from_module(module)
          anno -> SourceLocation.from_module_anno(module, anno)
        end
      end
    end
  end
end
