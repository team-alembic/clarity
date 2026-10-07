defmodule Clarity.Vertex.Ash.AttributeTest do
  use ExUnit.Case, async: true

  alias Ash.Resource.Info
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Attribute
  alias Demo.Accounts.User
  alias Spark.Dsl.Entity

  setup do
    attribute = User |> Info.attributes() |> List.first()

    vertex = %Attribute{
      attribute: attribute,
      resource: User
    }

    {:ok, vertex: vertex, attribute: attribute}
  end

  describe inspect(&Vertex.id/1) do
    test "returns correct unique identifier", %{vertex: vertex, attribute: attribute} do
      assert Vertex.id(vertex) == "ash-attribute:demo-accounts-user:#{attribute.name}"
    end
  end

  describe inspect(&Vertex.type_label/1) do
    test "returns attribute module name", %{vertex: vertex} do
      assert Vertex.type_label(vertex) == "Ash.Resource.Attribute"
    end
  end

  describe inspect(&Vertex.name/1) do
    test "returns attribute name", %{vertex: vertex, attribute: attribute} do
      assert Vertex.name(vertex) == to_string(attribute.name)
    end
  end

  describe inspect(&Clarity.Vertex.GraphGroupProvider.graph_group/1) do
    test "returns resource and attribute group", %{vertex: vertex} do
      result = Vertex.GraphGroupProvider.graph_group(vertex)
      assert result == ["Demo.Accounts.User", "Ash.Resource.Attribute"]
    end
  end

  describe inspect(&Clarity.Vertex.GraphShapeProvider.shape/1) do
    test "returns correct shape", %{vertex: vertex} do
      assert Vertex.GraphShapeProvider.shape(vertex) == "rectangle"
    end
  end

  describe inspect(&Clarity.Vertex.SourceLocationProvider.source_location/1) do
    test "returns SourceLocation from attribute entity", %{vertex: vertex, attribute: attribute} do
      source_location = Vertex.SourceLocationProvider.source_location(vertex)

      assert %Clarity.SourceLocation{} = source_location
      assert source_location.anno == Entity.anno(attribute)
      assert source_location.module == User
      assert source_location.application == :clarity
    end
  end

  describe inspect(&Clarity.Vertex.TooltipProvider.tooltip/1) do
    test "returns formatted overview with description", %{vertex: vertex, attribute: attribute} do
      overview = Vertex.TooltipProvider.tooltip(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "Attribute: `:#{attribute.name}`"
      assert overview_string =~ "Resource: `Demo.Accounts.User`"
    end

    test "handles attribute without description" do
      attribute = %Ash.Resource.Attribute{
        name: :id,
        type: Ash.Type.UUID,
        description: nil,
        public?: false
      }

      vertex = %Attribute{attribute: attribute, resource: User}
      overview = Vertex.TooltipProvider.tooltip(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "Attribute: `:id`"
      assert overview_string =~ "Type: `Ash.Type.UUID`"
      assert overview_string =~ "Public: `false`"
      refute overview_string =~ "\n\n\n"
    end

    test "handles private attribute" do
      attribute = %Ash.Resource.Attribute{
        name: :internal_id,
        type: Ash.Type.Integer,
        description: "Internal identifier",
        public?: false
      }

      vertex = %Attribute{attribute: attribute, resource: User}
      overview = Vertex.TooltipProvider.tooltip(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "Public: `false`"
    end
  end

  describe "Clarity.Vertex.HintProvider" do
    test "shows the resource, type and default, flagging visibility and nils" do
      vertex = %Attribute{attribute: Info.attribute(User, :representative), resource: User}

      assert Vertex.HintProvider.icon(vertex) == :attribute
      assert Vertex.HintProvider.badges(vertex) == ["public", "required"]

      assert Vertex.HintProvider.facts(vertex) == [
               {"Resource", "Demo.Accounts.User"},
               {"Type", "Ash.Type.Boolean"},
               {"Default", "false"}
             ]
    end

    test "flags sensitive and primary key attributes, omitting a nil default" do
      email = %Attribute{attribute: Info.attribute(User, :email), resource: User}
      id = %Attribute{attribute: Info.attribute(User, :id), resource: User}

      assert Vertex.HintProvider.badges(email) == ["public", "sensitive"]
      refute List.keymember?(Vertex.HintProvider.facts(email), "Default", 0)
      assert "primary key" in Vertex.HintProvider.badges(id)
    end
  end
end
