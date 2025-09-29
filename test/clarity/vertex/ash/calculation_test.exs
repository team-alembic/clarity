defmodule Clarity.Vertex.Ash.CalculationTest do
  use ExUnit.Case, async: true

  alias Ash.Resource.Info
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Calculation
  alias Demo.Accounts.User
  alias Spark.Dsl.Entity

  describe "Clarity.Vertex protocol implementation for Ash.Calculation" do
    setup do
      # Get a real calculation from the Demo.Accounts.User resource
      calculation = User |> Info.calculations() |> List.first()

      vertex = %Calculation{
        calculation: calculation,
        resource: User
      }

      {:ok, vertex: vertex, calculation: calculation}
    end

    test "unique_id/1 returns correct unique identifier", %{vertex: vertex, calculation: calculation} do
      assert Vertex.unique_id(vertex) == "calculation:Demo.Accounts.User:#{calculation.name}"
    end

    test "graph_id/1 returns correct graph identifier", %{vertex: vertex, calculation: calculation} do
      result = Vertex.graph_id(vertex)
      assert IO.iodata_to_binary(result) == "Demo.Accounts.User_#{calculation.name}"
    end

    test "graph_group/1 returns resource and calculation group", %{vertex: vertex} do
      result = Vertex.graph_group(vertex)
      assert result == ["Demo.Accounts.User", "Ash.Resource.Calculation"]
    end

    test "type_label/1 returns calculation module name", %{vertex: vertex} do
      assert Vertex.type_label(vertex) == "Ash.Resource.Calculation"
    end

    test "render_name/1 returns calculation name", %{vertex: vertex, calculation: calculation} do
      assert Vertex.render_name(vertex) == to_string(calculation.name)
    end

    test "dot_shape/1 returns correct shape", %{vertex: vertex} do
      assert Vertex.dot_shape(vertex) == "promoter"
    end

    test "markdown_overview/1 returns formatted overview with description", %{vertex: vertex, calculation: calculation} do
      overview = Vertex.markdown_overview(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "Attribute: `:#{calculation.name}`"
      assert overview_string =~ "Resource: `Demo.Accounts.User`"
    end

    test "source_location/1 returns SourceLocation from calculation entity", %{vertex: vertex, calculation: calculation} do
      source_location = Vertex.source_location(vertex)

      assert %Clarity.SourceLocation{} = source_location
      assert source_location.anno == Entity.anno(calculation)
      assert source_location.module == User
      assert source_location.application == :clarity
    end
  end

  describe "Calculation struct" do
    test "enforces required keys" do
      assert_raise ArgumentError, fn ->
        struct!(Calculation, %{})
      end
    end

    test "creates struct with required calculation and resource fields" do
      calculation = %Ash.Resource.Calculation{name: :full_name, type: :string}
      vertex = %Calculation{calculation: calculation, resource: User}

      assert vertex.calculation == calculation
      assert vertex.resource == User
    end
  end

  describe "markdown_overview with different calculation types" do
    test "handles calculation without description" do
      calculation = %Ash.Resource.Calculation{
        name: :computed_value,
        type: :integer,
        description: nil,
        public?: false
      }

      vertex = %Calculation{calculation: calculation, resource: User}
      overview = Vertex.markdown_overview(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "Attribute: `:computed_value`"
      assert overview_string =~ "Type: `:integer`"
      assert overview_string =~ "Public: `false`"
      # Should not contain extra newlines from missing description
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
      overview = Vertex.markdown_overview(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "Public: `false`"
    end
  end
end
