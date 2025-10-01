defmodule Clarity.Introspector.Ash.SparkTest do
  use ExUnit.Case, async: true

  alias Ash.Resource.Info
  alias Clarity.Introspector.Ash.Spark, as: SparkIntrospector
  alias Clarity.Vertex.Ash.Action
  alias Clarity.Vertex.Ash.Aggregate
  alias Clarity.Vertex.Ash.Attribute
  alias Clarity.Vertex.Ash.Calculation
  alias Clarity.Vertex.Ash.Relationship
  alias Clarity.Vertex.Ash.Resource
  alias Clarity.Vertex.Root
  alias Clarity.Vertex.Spark.Entity, as: EntityVertex
  alias Demo.Accounts.User

  describe inspect(&SparkIntrospector.introspect_vertex/2) do
    test "creates action vertices from action entities" do
      resource_vertex = %Resource{resource: User}
      graph = Clarity.Graph.new()
      Clarity.Graph.add_vertex(graph, resource_vertex, %Root{})

      action = Info.action(User, :read)

      entity_vertex = %EntityVertex{
        module: User,
        path: [:actions],
        entity: action
      }

      assert {:ok,
              [
                {:vertex, %Action{action: ^action, resource: User}},
                {:edge, ^resource_vertex, %Action{}, :action},
                {:edge, ^entity_vertex, %Action{}, :ash_vertex}
              ]} = SparkIntrospector.introspect_vertex(entity_vertex, graph)
    end

    test "creates attribute vertices from attribute entities" do
      resource_vertex = %Resource{resource: User}
      graph = Clarity.Graph.new()
      Clarity.Graph.add_vertex(graph, resource_vertex, %Root{})

      attribute = Info.attribute(User, :first_name)

      entity_vertex = %EntityVertex{
        module: User,
        path: [:attributes],
        entity: attribute
      }

      assert {:ok,
              [
                {:vertex, %Attribute{attribute: ^attribute, resource: User}},
                {:edge, ^resource_vertex, %Attribute{}, :attribute},
                {:edge, ^entity_vertex, %Attribute{}, :ash_vertex}
              ]} = SparkIntrospector.introspect_vertex(entity_vertex, graph)
    end

    test "creates aggregate vertices from aggregate entities" do
      resource_vertex = %Resource{resource: User}
      graph = Clarity.Graph.new()
      Clarity.Graph.add_vertex(graph, resource_vertex, %Root{})

      aggregates = Info.aggregates(User)
      aggregate = List.first(aggregates)

      if aggregate do
        entity_vertex = %EntityVertex{
          module: User,
          path: [:aggregates],
          entity: aggregate
        }

        assert {:ok,
                [
                  {:vertex, %Aggregate{aggregate: ^aggregate, resource: User}},
                  {:edge, ^resource_vertex, %Aggregate{}, :aggregate},
                  {:edge, ^entity_vertex, %Aggregate{}, :ash_vertex}
                ]} = SparkIntrospector.introspect_vertex(entity_vertex, graph)
      end
    end

    test "creates calculation vertices from calculation entities" do
      resource_vertex = %Resource{resource: User}
      graph = Clarity.Graph.new()
      Clarity.Graph.add_vertex(graph, resource_vertex, %Root{})

      calculations = Info.calculations(User)
      calculation = List.first(calculations)

      if calculation do
        entity_vertex = %EntityVertex{
          module: User,
          path: [:calculations],
          entity: calculation
        }

        assert {:ok,
                [
                  {:vertex, %Calculation{calculation: ^calculation, resource: User}},
                  {:edge, ^resource_vertex, %Calculation{}, :calculation},
                  {:edge, ^entity_vertex, %Calculation{}, :ash_vertex}
                ]} = SparkIntrospector.introspect_vertex(entity_vertex, graph)
      end
    end

    test "creates relationship vertices from relationship entities" do
      resource_vertex = %Resource{resource: User}
      destination_resource_vertex = %Resource{resource: User}
      graph = Clarity.Graph.new()
      Clarity.Graph.add_vertex(graph, resource_vertex, %Root{})

      relationship = Info.relationship(User, :manager)

      entity_vertex = %EntityVertex{
        module: User,
        path: [:relationships],
        entity: relationship
      }

      assert {:ok,
              [
                {:vertex, %Relationship{relationship: ^relationship, resource: User}},
                {:edge, ^resource_vertex, %Relationship{}, :relationship},
                {:edge, ^entity_vertex, %Relationship{}, :ash_vertex},
                {:edge, %Relationship{}, ^destination_resource_vertex, :destination}
              ]} = SparkIntrospector.introspect_vertex(entity_vertex, graph)
    end

    test "returns unmet dependencies when resource not in graph" do
      graph = Clarity.Graph.new()

      action = Info.action(User, :read)

      entity_vertex = %EntityVertex{
        module: User,
        path: [:actions],
        entity: action
      }

      assert {:error, :unmet_dependencies} =
               SparkIntrospector.introspect_vertex(entity_vertex, graph)
    end

    test "returns unmet dependencies when relationship destination not in graph" do
      graph = Clarity.Graph.new()

      relationship = Info.relationship(User, :manager)

      entity_vertex = %EntityVertex{
        module: User,
        path: [:relationships],
        entity: relationship
      }

      assert {:error, :unmet_dependencies} =
               SparkIntrospector.introspect_vertex(entity_vertex, graph)
    end

    test "ignores non-Ash entities" do
      resource_vertex = %Resource{resource: User}
      graph = Clarity.Graph.new()
      Clarity.Graph.add_vertex(graph, resource_vertex, %Root{})

      entity_vertex = %EntityVertex{
        module: User,
        path: [:some_section],
        entity: %{some: :data}
      }

      assert {:ok, []} = SparkIntrospector.introspect_vertex(entity_vertex, graph)
    end
  end
end
