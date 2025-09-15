defmodule Clarity.Vertex.Ash.AttributeTest do
  use ExUnit.Case, async: true

  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Attribute
  alias Demo.Accounts.User

  describe "Clarity.Vertex protocol implementation for Ash.Attribute" do
    setup do
      # Create a mock attribute structure
      attribute = %Ash.Resource.Attribute{
        name: :first_name,
        type: Ash.Type.String,
        description: "User's first name",
        public?: true
      }

      vertex = %Attribute{
        attribute: attribute,
        resource: User
      }

      {:ok, vertex: vertex, attribute: attribute}
    end

    test "unique_id/1 returns correct unique identifier", %{vertex: vertex} do
      assert Vertex.unique_id(vertex) == "attribute:Demo.Accounts.User:first_name"
    end

    test "graph_id/1 returns correct graph identifier", %{vertex: vertex} do
      result = Vertex.graph_id(vertex)
      assert IO.iodata_to_binary(result) == "Demo.Accounts.User_first_name"
    end

    test "graph_group/1 returns resource and attribute group", %{vertex: vertex} do
      result = Vertex.graph_group(vertex)
      assert result == ["Demo.Accounts.User", "Ash.Resource.Attribute"]
    end

    test "type_label/1 returns attribute module name", %{vertex: vertex} do
      assert Vertex.type_label(vertex) == "Ash.Resource.Attribute"
    end

    test "render_name/1 returns attribute name", %{vertex: vertex} do
      assert Vertex.render_name(vertex) == "first_name"
    end

    test "dot_shape/1 returns correct shape", %{vertex: vertex} do
      assert Vertex.dot_shape(vertex) == "rectangle"
    end

    test "markdown_overview/1 returns formatted overview with description", %{vertex: vertex} do
      overview = Vertex.markdown_overview(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "Attribute: `:first_name`"
      assert overview_string =~ "Resource: `Demo.Accounts.User`"
      assert overview_string =~ "User's first name"
      assert overview_string =~ "Type: `Ash.Type.String`"
      assert overview_string =~ "Public: `true`"
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
