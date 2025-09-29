defmodule Clarity.Vertex.Ash.ActionTest do
  use ExUnit.Case, async: true

  alias Ash.Resource.Actions.Argument
  alias Ash.Resource.Actions.Read
  alias Ash.Resource.Info
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Action
  alias Demo.Accounts.User
  alias Spark.Dsl.Entity

  describe "Clarity.Vertex protocol implementation for Ash.Action" do
    setup do
      # Get a real action from the Demo.Accounts.User resource
      action = User |> Info.actions() |> List.first()

      vertex = %Action{
        action: action,
        resource: User
      }

      {:ok, vertex: vertex, action: action}
    end

    test "unique_id/1 returns correct unique identifier", %{vertex: vertex, action: action} do
      assert Vertex.unique_id(vertex) == "action:Demo.Accounts.User:#{action.name}"
    end

    test "graph_id/1 returns correct graph identifier", %{vertex: vertex, action: action} do
      result = Vertex.graph_id(vertex)
      assert IO.iodata_to_binary(result) == "Demo.Accounts.User_#{action.name}"
    end

    test "graph_group/1 returns resource and actions group", %{vertex: vertex} do
      result = Vertex.graph_group(vertex)
      assert result == ["Demo.Accounts.User", "Ash.Resource.Actions"]
    end

    test "type_label/1 returns action module name", %{vertex: vertex, action: action} do
      assert Vertex.type_label(vertex) == action.__struct__ |> Module.split() |> Enum.join(".")
    end

    test "render_name/1 returns action name", %{vertex: vertex, action: action} do
      assert Vertex.render_name(vertex) == to_string(action.name)
    end

    test "dot_shape/1 returns correct shape", %{vertex: vertex} do
      assert Vertex.dot_shape(vertex) == "cds"
    end

    test "markdown_overview/1 returns formatted overview", %{vertex: vertex, action: action} do
      overview = Vertex.markdown_overview(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "Action: `:#{action.name}`"
      assert overview_string =~ "Resource: `Demo.Accounts.User`"
    end

    test "source_location/1 returns SourceLocation from action entity", %{vertex: vertex, action: action} do
      source_location = Vertex.source_location(vertex)

      assert %Clarity.SourceLocation{} = source_location
      assert source_location.anno == Entity.anno(action)
      assert source_location.module == User
      assert source_location.application == :clarity
    end
  end

  describe "Action struct" do
    test "enforces required keys" do
      assert_raise ArgumentError, fn ->
        struct!(Action, %{})
      end
    end

    test "creates struct with required action and resource fields" do
      action = %Ash.Resource.Actions.Create{name: :create, type: :create}
      vertex = %Action{action: action, resource: User}

      assert vertex.action == action
      assert vertex.resource == User
    end
  end

  describe "markdown_overview with different action types" do
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
      overview = Vertex.markdown_overview(vertex)
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
      overview = Vertex.markdown_overview(vertex)
      overview_string = IO.iodata_to_binary(overview)

      refute overview_string =~ "## Arguments"
    end
  end
end
