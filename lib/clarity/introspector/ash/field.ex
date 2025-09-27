case Code.ensure_loaded(Ash) do
  {:module, Ash} ->
    defmodule Clarity.Introspector.Ash.Field do
      @moduledoc false

      @behaviour Clarity.Introspector

      alias Ash.Resource
      alias Ash.Resource.Aggregate
      alias Ash.Resource.Attribute
      alias Ash.Resource.Calculation
      alias Ash.Resource.Relationships.BelongsTo
      alias Ash.Resource.Relationships.HasMany
      alias Ash.Resource.Relationships.HasOne
      alias Ash.Resource.Relationships.ManyToMany
      alias Clarity.Vertex
      alias Clarity.Vertex.Ash.Resource, as: ResourceVertex

      @typep field() ::
               Attribute.t()
               | Aggregate.t()
               | Calculation.t()
               | Ash.Resource.Relationships.relationship()

      @impl Clarity.Introspector
      def source_vertex_types, do: [ResourceVertex]

      @impl Clarity.Introspector
      def introspect_vertex(%ResourceVertex{resource: resource} = resource_vertex, graph) do
        resource
        |> Resource.Info.fields()
        |> Enum.flat_map(fn field ->
          field_vertex = field_vertex(field, resource)
          edge_label = edge_label(field)

          base_results = [
            {:vertex, field_vertex},
            {:edge, resource_vertex, field_vertex, edge_label}
          ]

          # Add relationship target edges if applicable
          base_results ++ add_relationship_edges(field, field_vertex, graph)
        end)
      end

      def introspect_vertex(_vertex, _graph), do: []

      @spec add_relationship_edges(field :: field(), Vertex.t(), Clarity.Graph.t()) ::
              Clarity.Introspector.results()
      defp add_relationship_edges(%mod{destination: target_resource}, field_vertex, graph)
           when mod in [HasOne, BelongsTo, HasMany, ManyToMany] do
        target_resource_vertex =
          graph
          |> Clarity.Graph.vertices()
          |> Enum.find(&match?(%ResourceVertex{resource: ^target_resource}, &1))

        case target_resource_vertex do
          nil -> []
          target -> [{:edge, field_vertex, target, :relationship}]
        end
      end

      defp add_relationship_edges(_field, _field_vertex, _graph), do: []

      @spec field_vertex(field :: field(), resource :: Resource.t()) :: Vertex.t()
      defp field_vertex(%Attribute{} = attribute, resource),
        do: %Vertex.Ash.Attribute{attribute: attribute, resource: resource}

      defp field_vertex(%Aggregate{} = aggregate, resource),
        do: %Vertex.Ash.Aggregate{aggregate: aggregate, resource: resource}

      defp field_vertex(%Calculation{} = calculation, resource),
        do: %Vertex.Ash.Calculation{calculation: calculation, resource: resource}

      defp field_vertex(%mod{} = relationship, resource)
           when mod in [HasOne, BelongsTo, HasMany, ManyToMany],
           do: %Vertex.Ash.Relationship{relationship: relationship, resource: resource}

      @spec edge_label(field :: field()) :: :digraph.label()
      defp edge_label(%Attribute{}), do: :attribute
      defp edge_label(%Aggregate{}), do: :aggregate
      defp edge_label(%Calculation{}), do: :calculation

      defp edge_label(%mod{}) when mod in [HasOne, BelongsTo, HasMany, ManyToMany],
        do: :relationship
    end

  _ ->
    defmodule Clarity.Introspector.Ash.Field do
      @moduledoc false

      @behaviour Clarity.Introspector

      @impl Clarity.Introspector
      def source_vertex_types, do: []

      @impl Clarity.Introspector
      def introspect_vertex(_vertex, _graph), do: []
    end
end
