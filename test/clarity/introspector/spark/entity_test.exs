defmodule Clarity.Introspector.Spark.EntityTest do
  use ExUnit.Case, async: true

  alias Clarity.Introspector.Spark.Entity, as: EntityIntrospector
  alias Clarity.Vertex.Spark.Entity, as: EntityVertex
  alias Clarity.Vertex.Spark.Section
  alias Demo.Accounts.User

  describe inspect(&EntityIntrospector.introspect_vertex/2) do
    test "creates entity vertices from section" do
      graph = Clarity.Graph.new()

      section_vertex = %Section{
        module: User,
        path: [:attributes]
      }

      assert {:ok,
              [
                {:vertex,
                 %EntityVertex{module: User, path: [:attributes], entity: %{name: :id}} =
                   id_entity},
                {:edge, ^section_vertex, id_entity, :entity},
                {:vertex,
                 %EntityVertex{module: User, path: [:attributes], entity: %{name: :first_name}} =
                   first_name_entity},
                {:edge, ^section_vertex, first_name_entity, :entity},
                {:vertex,
                 %EntityVertex{module: User, path: [:attributes], entity: %{name: :last_name}} =
                   last_name_entity},
                {:edge, ^section_vertex, last_name_entity, :entity}
                | _rest
              ]} = EntityIntrospector.introspect_vertex(section_vertex, graph)
    end

    test "creates entities for actions section" do
      graph = Clarity.Graph.new()

      section_vertex = %Section{
        module: User,
        path: [:actions]
      }

      assert {:ok,
              [
                {:vertex, %EntityVertex{module: User, path: [:actions], entity: %{name: :me}} = me_entity},
                {:edge, ^section_vertex, me_entity, :entity}
                | _rest
              ]} = EntityIntrospector.introspect_vertex(section_vertex, graph)
    end

    test "creates entities for relationships section" do
      graph = Clarity.Graph.new()

      section_vertex = %Section{
        module: User,
        path: [:relationships]
      }

      assert {:ok,
              [
                {:vertex, %EntityVertex{module: User, path: [:relationships], entity: %{name: :manager}}},
                {:edge, ^section_vertex, %EntityVertex{}, :entity}
              ]} = EntityIntrospector.introspect_vertex(section_vertex, graph)
    end

    test "returns empty list for section with no entities" do
      graph = Clarity.Graph.new()

      section_vertex = %Section{
        module: User,
        path: [:postgres]
      }

      assert {:ok, []} = EntityIntrospector.introspect_vertex(section_vertex, graph)
    end
  end
end
