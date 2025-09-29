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
        |> Enum.reduce_while({:ok, []}, fn field, {:ok, acc} ->
          field_vertex = field_vertex(field, resource)
          edge_label = edge_label(field)

          base_results = [
            {:vertex, field_vertex},
            {:edge, resource_vertex, field_vertex, edge_label}
          ]

          case add_relationship_edges(field, field_vertex, resource_vertex, graph) do
            {:ok, edges} ->
              {:cont, {:ok, acc ++ base_results ++ edges}}

            {:error, :unmet_dependencies} ->
              {:halt, {:error, :unmet_dependencies}}
          end
        end)
      end

      @spec add_relationship_edges(field :: field(), Vertex.t(), Vertex.t(), Clarity.Graph.t()) ::
              Clarity.Introspector.result()
      defp add_relationship_edges(
             %mod{destination: target_resource},
             field_vertex,
             resource_vertex,
             graph
           )
           when mod in [HasOne, BelongsTo, HasMany, ManyToMany] do
        case_result =
          case resource_vertex do
            %ResourceVertex{resource: ^target_resource} ->
              resource_vertex

            %ResourceVertex{} ->
              graph
              |> Clarity.Graph.vertices()
              |> Enum.find(&match?(%ResourceVertex{resource: ^target_resource}, &1))
          end

        case case_result do
          nil -> {:error, :unmet_dependencies}
          target -> {:ok, [{:edge, field_vertex, target, :relationship}]}
        end
      end

      defp add_relationship_edges(_field, _field_vertex, _resource_vertex, _graph), do: {:ok, []}

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
      def introspect_vertex(_vertex, _graph), do: {:ok, []}
    end
end
