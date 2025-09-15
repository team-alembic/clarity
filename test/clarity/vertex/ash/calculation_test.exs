defmodule Clarity.Vertex.Ash.CalculationTest do
  use ExUnit.Case, async: true

  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Calculation
  alias Demo.Accounts.User

  describe "Clarity.Vertex protocol implementation for Ash.Calculation" do
    setup do
      # Create a mock calculation structure
      calculation = %Ash.Resource.Calculation{
        name: :is_super_admin?,
        type: :boolean,
        description: "Determines if user is a super admin",
        public?: true
      }

      vertex = %Calculation{
        calculation: calculation,
        resource: User
      }

      {:ok, vertex: vertex, calculation: calculation}
    end

    test "unique_id/1 returns correct unique identifier", %{vertex: vertex} do
      assert Vertex.unique_id(vertex) == "calculation:Demo.Accounts.User:is_super_admin?"
    end

    test "graph_id/1 returns correct graph identifier", %{vertex: vertex} do
      result = Vertex.graph_id(vertex)
      assert IO.iodata_to_binary(result) == "Demo.Accounts.User_is_super_admin?"
    end

    test "graph_group/1 returns resource and calculation group", %{vertex: vertex} do
      result = Vertex.graph_group(vertex)
      assert result == ["Demo.Accounts.User", "Ash.Resource.Calculation"]
    end

    test "type_label/1 returns calculation module name", %{vertex: vertex} do
      assert Vertex.type_label(vertex) == "Ash.Resource.Calculation"
    end

    test "render_name/1 returns calculation name", %{vertex: vertex} do
      assert Vertex.render_name(vertex) == "is_super_admin?"
    end

    test "dot_shape/1 returns correct shape", %{vertex: vertex} do
      assert Vertex.dot_shape(vertex) == "promoter"
    end

    test "markdown_overview/1 returns formatted overview with description", %{vertex: vertex} do
      overview = Vertex.markdown_overview(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "Attribute: `:is_super_admin?`"
      assert overview_string =~ "Resource: `Demo.Accounts.User`"
      assert overview_string =~ "Determines if user is a super admin"
      assert overview_string =~ "Type: `:boolean`"
      assert overview_string =~ "Public: `true`"
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
