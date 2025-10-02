defmodule Clarity.Vertex.Ash.ActionTest do
  use ExUnit.Case, async: true

  alias Ash.Resource.Actions.Argument
  alias Ash.Resource.Actions.Read
  alias Ash.Resource.Info
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Action
  alias Demo.Accounts.User
  alias Spark.Dsl.Entity

  setup do
    action = User |> Info.actions() |> List.first()

    vertex = %Action{
      action: action,
      resource: User
    }

    {:ok, vertex: vertex, action: action}
  end

  describe inspect(&Vertex.id/1) do
    test "returns correct unique identifier", %{vertex: vertex, action: action} do
      assert Vertex.id(vertex) == "ash-action:demo-accounts-user:#{action.name}"
    end
  end

  describe inspect(&Vertex.type_label/1) do
    test "returns action module name", %{vertex: vertex, action: action} do
      assert Vertex.type_label(vertex) == action.__struct__ |> Module.split() |> Enum.join(".")
    end
  end

  describe inspect(&Vertex.name/1) do
    test "returns action name", %{vertex: vertex, action: action} do
      assert Vertex.name(vertex) == to_string(action.name)
    end
  end

  describe inspect(&Clarity.Vertex.GraphGroupProvider.graph_group/1) do
    test "returns resource and actions group", %{vertex: vertex} do
      result = Vertex.GraphGroupProvider.graph_group(vertex)
      assert result == ["Demo.Accounts.User", "Ash.Resource.Actions"]
    end
  end

  describe inspect(&Clarity.Vertex.GraphShapeProvider.shape/1) do
    test "returns correct shape", %{vertex: vertex} do
      assert Vertex.GraphShapeProvider.shape(vertex) == "cds"
    end
  end

  describe inspect(&Clarity.Vertex.SourceLocationProvider.source_location/1) do
    test "returns SourceLocation from action entity", %{vertex: vertex, action: action} do
      source_location = Vertex.SourceLocationProvider.source_location(vertex)

      assert %Clarity.SourceLocation{} = source_location
      assert source_location.anno == Entity.anno(action)
      assert source_location.module == User
      assert source_location.application == :clarity
    end
  end

  describe inspect(&Clarity.Vertex.TooltipProvider.tooltip/1) do
    test "returns formatted overview", %{vertex: vertex, action: action} do
      overview = Vertex.TooltipProvider.tooltip(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "Action: `:#{action.name}`"
      assert overview_string =~ "Resource: `Demo.Accounts.User`"
    end

    test "handles action with arguments" do
      action = %Read{
        name: :by_name,
        type: :read,
        description: "Find by name",
        arguments: [
          %Argument{
            name: :first_name,
            type: Ash.Type.String,
            description: "First name to search for"
          },
          %Argument{
            name: :last_name,
            type: Ash.Type.String,
            description: nil
          }
        ]
      }

      vertex = %Action{action: action, resource: User}
      overview = Vertex.TooltipProvider.tooltip(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "## Arguments"
      assert overview_string =~ "- `:first_name` (`Ash.Type.String`): First name to search for"
      assert overview_string =~ "- `:last_name` (`Ash.Type.String`)"
    end

    test "handles action without arguments" do
      action = %Read{
        name: :list_all,
        type: :read,
        description: "List all users",
        arguments: []
      }

      vertex = %Action{action: action, resource: User}
      overview = Vertex.TooltipProvider.tooltip(vertex)
      overview_string = IO.iodata_to_binary(overview)

      refute overview_string =~ "## Arguments"
    end
  end
end
