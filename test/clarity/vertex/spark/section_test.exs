defmodule Clarity.Vertex.Spark.SectionTest do
  use ExUnit.Case, async: true

  alias Clarity.Vertex
  alias Clarity.Vertex.Spark.Section
  alias Demo.Accounts.User

  setup do
    vertex = %Section{module: User, path: [:attributes]}
    {:ok, vertex: vertex}
  end

  describe inspect(&Vertex.id/1) do
    test "returns correct unique identifier", %{vertex: vertex} do
      assert Vertex.id(vertex) == "spark-section:demo-accounts-user:attributes"
    end
  end

  describe inspect(&Vertex.type_label/1) do
    test "returns correct type label", %{vertex: vertex} do
      assert Vertex.type_label(vertex) == "Spark Section"
    end
  end

  describe inspect(&Vertex.name/1) do
    test "returns correct display name", %{vertex: vertex} do
      assert Vertex.name(vertex) == "attributes"
    end

    test "handles nested section paths" do
      vertex = %Section{module: User, path: [:foo, :bar, :baz]}
      assert Vertex.name(vertex) == "foo > bar > baz"
    end
  end

  describe inspect(&Clarity.Vertex.GraphShapeProvider.shape/1) do
    test "returns correct shape", %{vertex: vertex} do
      assert Vertex.GraphShapeProvider.shape(vertex) == "note"
    end
  end

  describe inspect(&Clarity.Vertex.SourceLocationProvider.source_location/1) do
    test "returns SourceLocation from module", %{vertex: vertex} do
      source_location = Vertex.SourceLocationProvider.source_location(vertex)

      assert %Clarity.SourceLocation{} = source_location
      assert source_location.application == :clarity
      assert source_location.module == User
    end
  end

  describe inspect(&Clarity.Vertex.TooltipProvider.tooltip/1) do
    test "returns formatted overview", %{vertex: vertex} do
      overview = Vertex.TooltipProvider.tooltip(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "**Module:** `Demo.Accounts.User`"
      assert overview_string =~ "**Section Path:** `[:attributes]`"
    end
  end
end
