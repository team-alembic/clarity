case Code.ensure_loaded(Spark) do
  {:module, Spark} ->
    defmodule Clarity.Introspector.Spark.Entity do
      @moduledoc false

      @behaviour Clarity.Introspector

      alias Clarity.Vertex.Spark.Entity, as: EntityVertex
      alias Clarity.Vertex.Spark.Section
      alias Spark.Dsl.Extension

      @impl Clarity.Introspector
      def source_vertex_types, do: [Section]

      @impl Clarity.Introspector
      def introspect_vertex(%Section{module: module, path: path} = section_vertex, _graph) do
        entities = Extension.get_entities(module, path)

        entity_entries =
          Enum.flat_map(entities, fn entity ->
            entity_vertex = %EntityVertex{module: module, path: path, entity: entity}

            [
              {:vertex, entity_vertex},
              {:edge, section_vertex, entity_vertex, :entity}
            ]
          end)

        {:ok, entity_entries}
      end
    end

  _ ->
    defmodule Clarity.Introspector.Spark.Entity do
      @moduledoc false

      @behaviour Clarity.Introspector

      @impl Clarity.Introspector
      def source_vertex_types, do: []

      @impl Clarity.Introspector
      def introspect_vertex(_vertex, _graph), do: {:ok, []}
    end
end
