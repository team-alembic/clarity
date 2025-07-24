defmodule AshAtlas.Resolver.Field do
  @behaviour AshAtlas.Resolver

  alias AshAtlas.Tree.Node

  @impl AshAtlas.Resolver
  def resolve(graph) do
    for %Node.Resource{resource: resource} = resource_vertex <- :digraph.vertices(graph),
        field <- Ash.Resource.Info.fields(resource) do
      field_node = field_node(field, resource)
      edge_label = edge_label(field)

      field_vertex = :digraph.add_vertex(graph, field_node, Node.unique_id(field_node))
      :digraph.add_edge(graph, resource_vertex, field_vertex, edge_label)

      resolve_field_targets(graph, field_vertex, field)
    end

    graph
  end

  @impl AshAtlas.Resolver
  def post_process(graph) do
    # No post-processing needed for the domain resolver
    graph
  end

  defp field_node(%Ash.Resource.Attribute{} = attribute, resource),
    do: %Node.Attribute{attribute: attribute, resource: resource}

  defp field_node(%Ash.Resource.Aggregate{} = aggregate, resource),
    do: %Node.Aggregate{aggregate: aggregate, resource: resource}

  defp field_node(%Ash.Resource.Calculation{} = calculation, resource),
    do: %Node.Calculation{calculation: calculation, resource: resource}

  defp field_node(%mod{} = relationship, resource)
       when mod in [
              Ash.Resource.Relationships.HasOne,
              Ash.Resource.Relationships.BelongsTo,
              Ash.Resource.Relationships.HasMany,
              Ash.Resource.Relationships.ManyToMany
            ],
       do: %Node.Relationship{relationship: relationship, resource: resource}

  defp edge_label(%Ash.Resource.Attribute{}), do: "attribute"
  defp edge_label(%Ash.Resource.Aggregate{}), do: "aggregate"
  defp edge_label(%Ash.Resource.Calculation{}), do: "calculation"

  defp edge_label(%mod{})
       when mod in [
              Ash.Resource.Relationships.HasOne,
              Ash.Resource.Relationships.BelongsTo,
              Ash.Resource.Relationships.HasMany,
              Ash.Resource.Relationships.ManyToMany
            ],
       do: "relationship"

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
        &match?(%Node.Resource{resource: ^target_resource}, &1)
      )

    :digraph.add_edge(graph, field_vertex, target_resource_vertex, "relationship")
  end

  defp resolve_field_targets(_, _, _), do: :ok
end
