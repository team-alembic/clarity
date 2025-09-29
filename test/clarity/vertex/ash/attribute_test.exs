defmodule Clarity.Vertex.Ash.AttributeTest do
  use ExUnit.Case, async: true

  alias Ash.Resource.Info
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Attribute
  alias Demo.Accounts.User
  alias Spark.Dsl.Entity

  describe "Clarity.Vertex protocol implementation for Ash.Attribute" do
    setup do
      # Get a real attribute from the Demo.Accounts.User resource
      attribute = User |> Info.attributes() |> List.first()

      vertex = %Attribute{
        attribute: attribute,
        resource: User
      }

      {:ok, vertex: vertex, attribute: attribute}
    end

    test "unique_id/1 returns correct unique identifier", %{vertex: vertex, attribute: attribute} do
      assert Vertex.unique_id(vertex) == "attribute:Demo.Accounts.User:#{attribute.name}"
    end

    test "graph_id/1 returns correct graph identifier", %{vertex: vertex, attribute: attribute} do
      result = Vertex.graph_id(vertex)
      assert IO.iodata_to_binary(result) == "Demo.Accounts.User_#{attribute.name}"
    end

    test "graph_group/1 returns resource and attribute group", %{vertex: vertex} do
      result = Vertex.graph_group(vertex)
      assert result == ["Demo.Accounts.User", "Ash.Resource.Attribute"]
    end

    test "type_label/1 returns attribute module name", %{vertex: vertex} do
      assert Vertex.type_label(vertex) == "Ash.Resource.Attribute"
    end

    test "render_name/1 returns attribute name", %{vertex: vertex, attribute: attribute} do
      assert Vertex.render_name(vertex) == to_string(attribute.name)
    end

    test "dot_shape/1 returns correct shape", %{vertex: vertex} do
      assert Vertex.dot_shape(vertex) == "rectangle"
    end

    test "markdown_overview/1 returns formatted overview with description", %{vertex: vertex, attribute: attribute} do
      overview = Vertex.markdown_overview(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "Attribute: `:#{attribute.name}`"
      assert overview_string =~ "Resource: `Demo.Accounts.User`"
    end

    test "source_anno/1 returns annotation from attribute entity", %{vertex: vertex, attribute: attribute} do
      assert Vertex.source_anno(vertex) == Entity.anno(attribute)
    end
  end

  describe "Attribute struct" do
    test "enforces required keys" do
      assert_raise ArgumentError, fn ->
        struct!(Attribute, %{})
      end
    end

    test "creates struct with required attribute and resource fields" do
      attribute = %Ash.Resource.Attribute{name: :email, type: Ash.Type.String}
      vertex = %Attribute{attribute: attribute, resource: User}

      assert vertex.attribute == attribute
      assert vertex.resource == User
    end
  end

  describe "markdown_overview with different attribute types" do
    test "handles attribute without description" do
      attribute = %Ash.Resource.Attribute{
        name: :id,
        type: Ash.Type.UUID,
        description: nil,
        public?: false
      }

      vertex = %Attribute{attribute: attribute, resource: User}
      overview = Vertex.markdown_overview(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "Attribute: `:id`"
      assert overview_string =~ "Type: `Ash.Type.UUID`"
      assert overview_string =~ "Public: `false`"
      # Should not contain extra newlines from missing description
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
      overview = Vertex.markdown_overview(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "Public: `false`"
    end
  end
end
