defmodule Clarity.Vertex.Ash.CalculationTest do
  use ExUnit.Case, async: true

  alias Ash.Resource.Info
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Calculation
  alias Demo.Accounts.User
  alias Spark.Dsl.Entity

  setup do
    calculation = User |> Info.calculations() |> List.first()

    vertex = %Calculation{
      calculation: calculation,
      resource: User
    }

    {:ok, vertex: vertex, calculation: calculation}
  end

  describe inspect(&Vertex.id/1) do
    test "returns correct unique identifier", %{vertex: vertex} do
      assert Vertex.id(vertex) == "ash-calculation:demo-accounts-user:is-super-admin"
    end
  end

  describe inspect(&Vertex.type_label/1) do
    test "returns calculation module name", %{vertex: vertex} do
      assert Vertex.type_label(vertex) == "Ash.Resource.Calculation"
    end
  end

  describe inspect(&Vertex.name/1) do
    test "returns calculation name", %{vertex: vertex, calculation: calculation} do
      assert Vertex.name(vertex) == to_string(calculation.name)
    end
  end

  describe inspect(&Clarity.Vertex.GraphGroupProvider.graph_group/1) do
    test "returns resource and calculation group", %{vertex: vertex} do
      result = Vertex.GraphGroupProvider.graph_group(vertex)
      assert result == ["Demo.Accounts.User", "Ash.Resource.Calculation"]
    end
  end

  describe inspect(&Clarity.Vertex.GraphShapeProvider.shape/1) do
    test "returns correct shape", %{vertex: vertex} do
      assert Vertex.GraphShapeProvider.shape(vertex) == "promoter"
    end
  end

  describe inspect(&Clarity.Vertex.SourceLocationProvider.source_location/1) do
    test "returns SourceLocation from calculation entity", %{vertex: vertex, calculation: calculation} do
      source_location = Vertex.SourceLocationProvider.source_location(vertex)

      assert %Clarity.SourceLocation{} = source_location
      assert source_location.anno == Entity.anno(calculation)
      assert source_location.module == User
      assert source_location.application == :clarity
    end
  end

  describe inspect(&Clarity.Vertex.TooltipProvider.tooltip/1) do
    test "returns formatted overview with description", %{vertex: vertex, calculation: calculation} do
      overview = Vertex.TooltipProvider.tooltip(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "Attribute: `:#{calculation.name}`"
      assert overview_string =~ "Resource: `Demo.Accounts.User`"
    end

    test "handles calculation without description" do
      calculation = %Ash.Resource.Calculation{
        name: :computed_value,
        type: :integer,
        description: nil,
        public?: false
      }

      vertex = %Calculation{calculation: calculation, resource: User}
      overview = Vertex.TooltipProvider.tooltip(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "Attribute: `:computed_value`"
      assert overview_string =~ "Type: `:integer`"
      assert overview_string =~ "Public: `false`"
      refute overview_string =~ "\n\n\n"
    end

    test "handles private calculation" do
      calculation = %Ash.Resource.Calculation{
        name: :internal_score,
        type: :float,
        description: "Internal scoring mechanism",
        public?: false
      }

      vertex = %Calculation{calculation: calculation, resource: User}
      overview = Vertex.TooltipProvider.tooltip(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "Public: `false`"
    end
  end
end
