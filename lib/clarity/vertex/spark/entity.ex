with {:module, Spark} <- Code.ensure_loaded(Spark) do
  defmodule Clarity.Vertex.Spark.Entity do
    @moduledoc """
    Vertex implementation for Spark DSL entities.

    Represents a configured entity within a Spark DSL section.
    For example, an individual attribute in the `[:attributes]` section of an Ash Resource.
    """

    alias Clarity.SourceLocation
    alias Clarity.Vertex.HintProvider
    alias Spark.Dsl.Entity

    @type t() :: %__MODULE__{
            module: module(),
            path: [atom()],
            entity: struct()
          }
    @enforce_keys [:module, :path, :entity]
    defstruct [:module, :path, :entity]

    @doc """
    The value that names an entity: its `:name` field if it has one, or else
    the field its DSL definition identifies it by (the definition's
    `identifier`, or else its first argument), or else the definition's name.
    A domain's `resource` entries, for example, are named by their resource.
    """
    @spec name_value(t()) :: term()
    def name_value(%__MODULE__{entity: entity} = vertex) do
      case Map.get(entity, :name) do
        nil -> definition_name_value(vertex)
        name -> name
      end
    end

    @doc """
    The entity's name, as `name_value/1` finds it: a module as its full name,
    and never the entity struct itself.
    """
    @spec label(t()) :: String.t()
    def label(vertex) do
      case name_value(vertex) do
        value when is_binary(value) -> value
        value when is_atom(value) -> atom_label(value)
        value -> inspect(value, limit: 5, printable_limit: 60)
      end
    end

    @spec atom_label(atom()) :: String.t()
    defp atom_label(atom) do
      case Atom.to_string(atom) do
        "Elixir." <> _ -> inspect(atom)
        string -> string
      end
    end

    @spec definition_name_value(t()) :: term()
    defp definition_name_value(%__MODULE__{module: module, entity: %struct{} = entity}) do
      case definition(module, struct) do
        nil -> struct |> Module.split() |> List.last()
        definition -> naming_value(definition, entity)
      end
    end

    # Not a struct, so there is no definition to name it by.
    defp definition_name_value(%__MODULE__{entity: entity}), do: entity

    @spec naming_value(Entity.t(), struct()) :: term()
    defp naming_value(definition, entity) do
      case naming_field(definition) do
        nil -> definition.name
        field -> Map.get(entity, field) || definition.name
      end
    end

    @spec naming_field(Entity.t()) :: atom() | nil
    defp naming_field(%Entity{identifier: field}) when is_atom(field) and not is_nil(field),
      do: field

    defp naming_field(%Entity{args: [{:optional, field} | _]}), do: field
    defp naming_field(%Entity{args: [{:optional, field, _default} | _]}), do: field
    defp naming_field(%Entity{args: [field | _]}) when is_atom(field), do: field
    defp naming_field(_definition), do: nil

    # The DSL definition, among `module`'s extensions, whose target is `struct`.
    @spec definition(module(), module()) :: Entity.t() | nil
    defp definition(module, struct) do
      module
      |> Spark.extensions()
      |> Enum.flat_map(& &1.sections())
      |> Enum.find_value(&find_in_section(&1, struct))
    end

    @spec find_in_section(Spark.Dsl.Section.t(), module()) :: Entity.t() | nil
    defp find_in_section(section, struct) do
      Enum.find_value(section.entities, &find_in_entity(&1, struct)) ||
        Enum.find_value(section.sections, &find_in_section(&1, struct))
    end

    @spec find_in_entity(Entity.t(), module()) :: Entity.t() | nil
    defp find_in_entity(%Entity{target: struct} = definition, struct), do: definition

    defp find_in_entity(definition, struct) do
      definition.entities
      |> Enum.flat_map(fn {_name, entities} -> entities end)
      |> Enum.find_value(&find_in_entity(&1, struct))
    end

    defimpl Clarity.Vertex do
      alias Clarity.Vertex.Util

      @impl Clarity.Vertex
      def id(%@for{module: module, path: path, entity: entity}) do
        Util.id(@for, [module, inspect(path), entity])
      end

      @impl Clarity.Vertex
      def type_label(_vertex), do: "Spark Entity"

      @impl Clarity.Vertex
      def name(vertex), do: @for.label(vertex)
    end

    defimpl Clarity.Vertex.ModuleProvider do
      @impl Clarity.Vertex.ModuleProvider
      def module(vertex) do
        case @for.name_value(vertex) do
          module when is_atom(module) and not is_nil(module) ->
            if match?("Elixir." <> _, Atom.to_string(module)), do: module

          _value ->
            nil
        end
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
      def tooltip(%@for{module: module, path: path} = vertex) do
        entity_name = @for.label(vertex)

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

    defimpl Clarity.Vertex.HintProvider do
      @impl HintProvider
      def icon(_vertex), do: :entity

      @impl HintProvider
      def badges(_vertex), do: []

      @impl HintProvider
      def facts(%@for{module: module, path: path}),
        do: [{"Module", inspect(module)}, {"Section", Enum.join(path, " > ")}]
    end
  end
end
