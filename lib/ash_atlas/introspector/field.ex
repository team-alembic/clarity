defmodule AshAtlas.Introspector.Field do
  @moduledoc false

  @behaviour AshAtlas.Introspector

  alias Ash.Resource
  alias Ash.Resource.Aggregate
  alias Ash.Resource.Attribute
  alias Ash.Resource.Calculation
  alias Ash.Resource.Relationships.BelongsTo
  alias Ash.Resource.Relationships.HasMany
  alias Ash.Resource.Relationships.HasOne
  alias Ash.Resource.Relationships.ManyToMany
  alias AshAtlas.Vertex

  @typep field() ::
           Attribute.t()
           | Aggregate.t()
           | Calculation.t()
           | Ash.Resource.Relationships.relationship()

  @impl AshAtlas.Introspector
  def introspect(graph) do
    for %Vertex.Resource{resource: resource} = resource_vertex <- :digraph.vertices(graph),
        field <- Resource.Info.fields(resource) do
      field_vertex = field_vertex(field, resource)
      edge_label = edge_label(field)

      field_vertex = :digraph.add_vertex(graph, field_vertex, Vertex.unique_id(field_vertex))
      :digraph.add_edge(graph, resource_vertex, field_vertex, edge_label)

      resolve_field_targets(graph, field_vertex, field)
    end

    graph
  end

  @spec field_vertex(field :: field(), resource :: Resource.t()) :: Vertex.t()
  defp field_vertex(%Attribute{} = attribute, resource),
    do: %Vertex.Attribute{attribute: attribute, resource: resource}

  defp field_vertex(%Aggregate{} = aggregate, resource),
    do: %Vertex.Aggregate{aggregate: aggregate, resource: resource}

  defp field_vertex(%Calculation{} = calculation, resource),
    do: %Vertex.Calculation{calculation: calculation, resource: resource}

  defp field_vertex(%mod{} = relationship, resource)
       when mod in [HasOne, BelongsTo, HasMany, ManyToMany],
       do: %Vertex.Relationship{relationship: relationship, resource: resource}

  @spec edge_label(field :: field()) :: :digraph.label()
  defp edge_label(%Attribute{}), do: :attribute
  defp edge_label(%Aggregate{}), do: :aggregate
  defp edge_label(%Calculation{}), do: :calculation

  defp edge_label(%mod{}) when mod in [HasOne, BelongsTo, HasMany, ManyToMany], do: :relationship

  @spec resolve_field_targets(
          graph :: :digraph.graph(),
          field_vertex :: :digraph.vertex(),
          field :: field()
        ) :: :ok
  defp resolve_field_targets(graph, field_vertex, %mod{destination: target_resource})
       when mod in [HasOne, BelongsTo, HasMany, ManyToMany] do
    target_resource_vertex =
      Enum.find(
        :digraph.vertices(graph),
        &match?(%Vertex.Resource{resource: ^target_resource}, &1)
      )

    :digraph.add_edge(graph, field_vertex, target_resource_vertex, :relationship)

    :ok
  end

  defp resolve_field_targets(_, _, _), do: :ok
end
