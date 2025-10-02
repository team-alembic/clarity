defmodule Clarity.Vertex.Spark.EntityTest do
  use ExUnit.Case, async: true

  alias Ash.Resource.Info
  alias Clarity.Vertex
  alias Clarity.Vertex.Spark.Entity
  alias Demo.Accounts.User

  setup do
    attribute = User |> Info.attributes() |> List.first()
    vertex = %Entity{module: User, path: [:attributes], entity: attribute}
    {:ok, vertex: vertex, attribute: attribute}
  end

  describe inspect(&Vertex.id/1) do
    test "returns correct unique identifier", %{vertex: vertex} do
      id = Vertex.id(vertex)
      assert String.starts_with?(id, "spark-entity:demo-accounts-user:attributes:")
    end
  end

  describe inspect(&Vertex.type_label/1) do
    test "returns correct type label", %{vertex: vertex} do
      assert Vertex.type_label(vertex) == "Spark Entity"
    end
  end

  describe inspect(&Vertex.name/1) do
    test "returns entity name", %{vertex: vertex, attribute: attribute} do
      assert Vertex.name(vertex) == to_string(attribute.name)
    end

    test "handles entity without name field" do
      entity_without_name = %{some_field: "value"}
      vertex = %Entity{module: User, path: [:test], entity: entity_without_name}
      assert Vertex.name(vertex) == inspect(entity_without_name)
    end
  end

  describe inspect(&Clarity.Vertex.GraphShapeProvider.shape/1) do
    test "returns correct shape", %{vertex: vertex} do
      assert Vertex.GraphShapeProvider.shape(vertex) == "box"
    end
  end

  describe inspect(&Clarity.Vertex.SourceLocationProvider.source_location/1) do
    test "returns SourceLocation from entity annotation", %{vertex: vertex, attribute: attribute} do
      source_location = Vertex.SourceLocationProvider.source_location(vertex)

      assert %Clarity.SourceLocation{} = source_location
      assert source_location.module == User
      assert source_location.application == :clarity

      entity_anno = Spark.Dsl.Entity.anno(attribute)

      if entity_anno do
        assert source_location.anno == entity_anno
      end
    end
  end

  describe inspect(&Clarity.Vertex.TooltipProvider.tooltip/1) do
    test "returns formatted overview", %{vertex: vertex, attribute: attribute} do
      overview = Vertex.TooltipProvider.tooltip(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "**Module:** `Demo.Accounts.User`"
      assert overview_string =~ "**Section Path:** `[:attributes]`"
      assert overview_string =~ "**Entity:** `#{attribute.name}`"
    end
  end
end
