with {:module, Spark} <- Code.ensure_loaded(Spark) do
  defmodule Clarity.Vertex.Spark.Entity do
    @moduledoc """
    Vertex implementation for Spark DSL entities.

    Represents a configured entity within a Spark DSL section.
    For example, an individual attribute in the `[:attributes]` section of an Ash Resource.
    """

    alias Clarity.SourceLocation
    alias Spark.Dsl.Entity

    @type t() :: %__MODULE__{
            module: module(),
            path: [atom()],
            entity: struct()
          }
    @enforce_keys [:module, :path, :entity]
    defstruct [:module, :path, :entity]

    defimpl Clarity.Vertex do
      alias Clarity.Vertex.Util

      @impl Clarity.Vertex
      def id(%@for{module: module, path: path, entity: entity}) do
        Util.id(@for, [module, inspect(path), entity])
      end

      @impl Clarity.Vertex
      def type_label(_vertex), do: "Spark Entity"

      @impl Clarity.Vertex
      def name(%@for{entity: entity}) do
        entity |> Map.get(:name, inspect(entity)) |> to_string()
      end
    end

    defimpl Clarity.Vertex.GraphShapeProvider do
      @impl Clarity.Vertex.GraphShapeProvider
      def shape(_vertex), do: "box"
    end

    defimpl Clarity.Vertex.SourceLocationProvider do
      alias Entity, as: SparkEntity

      @impl Clarity.Vertex.SourceLocationProvider
      def source_location(%{module: module, entity: entity}) do
        case SparkEntity.anno(entity) do
          nil -> SourceLocation.from_module(module)
          anno -> SourceLocation.from_module_anno(module, anno)
        end
      end
    end

    defimpl Clarity.Vertex.TooltipProvider do
      @impl Clarity.Vertex.TooltipProvider
      def tooltip(%@for{module: module, path: path, entity: entity}) do
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
    end
  end
end
