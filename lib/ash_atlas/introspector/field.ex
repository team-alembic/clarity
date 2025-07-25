defmodule AshAtlas.Introspector.Field do
  @moduledoc false

  @behaviour AshAtlas.Introspector

  alias AshAtlas.Vertex

  @impl AshAtlas.Introspector
  def introspect(graph) do
    for %Vertex.Resource{resource: resource} = resource_vertex <- :digraph.vertices(graph),
        field <- Ash.Resource.Info.fields(resource) do
      field_vertex = field_vertex(field, resource)
      edge_label = edge_label(field)

      field_vertex = :digraph.add_vertex(graph, field_vertex, Vertex.unique_id(field_vertex))
      :digraph.add_edge(graph, resource_vertex, field_vertex, edge_label)

      resolve_field_targets(graph, field_vertex, field)
    end

    graph
  end

  defp field_vertex(%Ash.Resource.Attribute{} = attribute, resource),
    do: %Vertex.Attribute{attribute: attribute, resource: resource}

  defp field_vertex(%Ash.Resource.Aggregate{} = aggregate, resource),
    do: %Vertex.Aggregate{aggregate: aggregate, resource: resource}

  defp field_vertex(%Ash.Resource.Calculation{} = calculation, resource),
    do: %Vertex.Calculation{calculation: calculation, resource: resource}

  defp field_vertex(%mod{} = relationship, resource)
       when mod in [
              Ash.Resource.Relationships.HasOne,
              Ash.Resource.Relationships.BelongsTo,
              Ash.Resource.Relationships.HasMany,
              Ash.Resource.Relationships.ManyToMany
            ],
       do: %Vertex.Relationship{relationship: relationship, resource: resource}

  defp edge_label(%Ash.Resource.Attribute{}), do: :attribute
  defp edge_label(%Ash.Resource.Aggregate{}), do: :aggregate
  defp edge_label(%Ash.Resource.Calculation{}), do: :calculation

  defp edge_label(%mod{})
       when mod in [
              Ash.Resource.Relationships.HasOne,
              Ash.Resource.Relationships.BelongsTo,
              Ash.Resource.Relationships.HasMany,
              Ash.Resource.Relationships.ManyToMany
            ],
       do: :relationship

  defp resolve_field_targets(graph, field_vertex, %mod{destination: target_resource})
       when mod in [
              Ash.Resource.Relationships.HasOne,
              Ash.Resource.Relationships.BelongsTo,
              Ash.Resource.Relationships.HasMany,
              Ash.Resource.Relationships.ManyToMany
            ] do
    target_resource_vertex =
      Enum.find(
        :digraph.vertices(graph),
        &match?(%Vertex.Resource{resource: ^target_resource}, &1)
      )

    :digraph.add_edge(graph, field_vertex, target_resource_vertex, :relationship)
  end

  defp resolve_field_targets(_, _, _), do: :ok
end
