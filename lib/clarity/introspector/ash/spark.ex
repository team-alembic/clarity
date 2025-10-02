with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Introspector.Ash.Spark do
    @moduledoc false

    @behaviour Clarity.Introspector

    alias Ash.Resource.Actions.Create
    alias Ash.Resource.Actions.Destroy
    alias Ash.Resource.Actions.Read
    alias Ash.Resource.Actions.Update
    alias Ash.Resource.Relationships.BelongsTo
    alias Ash.Resource.Relationships.HasMany
    alias Ash.Resource.Relationships.HasOne
    alias Ash.Resource.Relationships.ManyToMany
    alias Clarity.Graph
    alias Clarity.Vertex.Ash.Action
    alias Clarity.Vertex.Ash.Aggregate
    alias Clarity.Vertex.Ash.Attribute
    alias Clarity.Vertex.Ash.Calculation
    alias Clarity.Vertex.Ash.Policy
    alias Clarity.Vertex.Ash.Relationship
    alias Clarity.Vertex.Ash.Resource
    alias Clarity.Vertex.Spark.Entity, as: EntityVertex

    @impl Clarity.Introspector
    def source_vertex_types, do: [EntityVertex]

    @impl Clarity.Introspector
    def introspect_vertex(%EntityVertex{module: module, entity: entity} = entity_vertex, graph) do
      with {:ash_vertex, ash_vertex} when not is_nil(ash_vertex) <-
             {:ash_vertex, create_ash_vertex(entity, module)},
           {:ok, resource_vertex} <- fetch_resource_vertex(graph, module),
           {:ok, edges} <- add_relationship_edges(entity, ash_vertex, graph) do
        edge_label = edge_label(entity)

        {:ok,
         [
           {:vertex, ash_vertex},
           {:edge, resource_vertex, ash_vertex, edge_label},
           {:edge, entity_vertex, ash_vertex, :ash_vertex}
           | edges
         ]}
      else
        {:ash_vertex, nil} -> {:ok, []}
        {:error, :unmet_dependencies} -> {:error, :unmet_dependencies}
      end
    end

    @spec create_ash_vertex(struct(), module()) ::
            Action.t()
            | Attribute.t()
            | Aggregate.t()
            | Calculation.t()
            | Relationship.t()
            | Policy.t()
            | nil
    defp create_ash_vertex(%Ash.Resource.Actions.Action{} = entity, resource),
      do: %Action{action: entity, resource: resource}

    defp create_ash_vertex(%Create{} = entity, resource),
      do: %Action{action: entity, resource: resource}

    defp create_ash_vertex(%Read{} = entity, resource),
      do: %Action{action: entity, resource: resource}

    defp create_ash_vertex(%Update{} = entity, resource),
      do: %Action{action: entity, resource: resource}

    defp create_ash_vertex(%Destroy{} = entity, resource),
      do: %Action{action: entity, resource: resource}

    defp create_ash_vertex(%Ash.Resource.Attribute{} = entity, resource),
      do: %Attribute{attribute: entity, resource: resource}

    defp create_ash_vertex(%Ash.Resource.Aggregate{} = entity, resource),
      do: %Aggregate{aggregate: entity, resource: resource}

    defp create_ash_vertex(%Ash.Resource.Calculation{} = entity, resource),
      do: %Calculation{calculation: entity, resource: resource}

    defp create_ash_vertex(%HasOne{} = entity, resource),
      do: %Relationship{relationship: entity, resource: resource}

    defp create_ash_vertex(%BelongsTo{} = entity, resource),
      do: %Relationship{relationship: entity, resource: resource}

    defp create_ash_vertex(%HasMany{} = entity, resource),
      do: %Relationship{relationship: entity, resource: resource}

    defp create_ash_vertex(%ManyToMany{} = entity, resource),
      do: %Relationship{relationship: entity, resource: resource}

    defp create_ash_vertex(%Ash.Policy.Policy{} = entity, resource),
      do: %Policy{policy: entity, resource: resource}

    defp create_ash_vertex(_entity, _resource), do: nil

    @spec fetch_resource_vertex(Graph.t(), module()) ::
            {:ok, Resource.t()} | {:error, :unmet_dependencies}
    defp fetch_resource_vertex(graph, module) do
      graph
      |> Graph.vertices(type: Resource, field_equal: {:resource, module})
      |> case do
        [] -> {:error, :unmet_dependencies}
        [vertex] -> {:ok, vertex}
      end
    end

    @spec add_relationship_edges(struct(), Clarity.Vertex.t(), Graph.t()) ::
            {:ok, list()} | {:error, :unmet_dependencies}
    defp add_relationship_edges(%HasOne{} = entity, ash_vertex, graph),
      do: add_destination_edge(entity, ash_vertex, graph)

    defp add_relationship_edges(%BelongsTo{} = entity, ash_vertex, graph),
      do: add_destination_edge(entity, ash_vertex, graph)

    defp add_relationship_edges(%HasMany{} = entity, ash_vertex, graph),
      do: add_destination_edge(entity, ash_vertex, graph)

    defp add_relationship_edges(%ManyToMany{} = entity, ash_vertex, graph),
      do: add_destination_edge(entity, ash_vertex, graph)

    defp add_relationship_edges(_entity, _ash_vertex, _graph), do: {:ok, []}

    @spec add_destination_edge(struct(), Relationship.t(), Graph.t()) ::
            {:ok, list()} | {:error, :unmet_dependencies}
    defp add_destination_edge(entity, ash_vertex, graph) do
      case fetch_resource_vertex(graph, entity.destination) do
        {:ok, destination_vertex} ->
          {:ok, [{:edge, ash_vertex, destination_vertex, :destination}]}

        {:error, :unmet_dependencies} ->
          {:error, :unmet_dependencies}
      end
    end

    @spec edge_label(struct()) :: atom()
    defp edge_label(%Ash.Resource.Actions.Action{}), do: :action
    defp edge_label(%Create{}), do: :action
    defp edge_label(%Read{}), do: :action
    defp edge_label(%Update{}), do: :action
    defp edge_label(%Destroy{}), do: :action
    defp edge_label(%Ash.Resource.Attribute{}), do: :attribute
    defp edge_label(%Ash.Resource.Aggregate{}), do: :aggregate
    defp edge_label(%Ash.Resource.Calculation{}), do: :calculation
    defp edge_label(%HasOne{}), do: :relationship
    defp edge_label(%BelongsTo{}), do: :relationship
    defp edge_label(%HasMany{}), do: :relationship
    defp edge_label(%ManyToMany{}), do: :relationship
    defp edge_label(%Ash.Policy.Policy{}), do: :policy
  end
end
