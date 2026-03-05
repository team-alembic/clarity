defmodule Clarity.Graph.Backend.CypherTest do
  use ExUnit.Case, async: true

  alias Clarity.Graph.Backend.Cypher
  alias Clarity.Vertex.Root

  describe "query_to_cypher/2" do
    test "true query produces empty WHERE clause" do
      assert Cypher.query_to_cypher(true) == ""
    end

    test "false query" do
      assert Cypher.query_to_cypher(false) == " WHERE false"
    end

    test "equality on vertex_type" do
      query = {:==, :vertex_type, Clarity.Vertex.Module}
      assert Cypher.query_to_cypher(query) == " WHERE v.type = 'Elixir.Clarity.Vertex.Module'"
    end

    test "equality on vertex_id" do
      query = {:==, :vertex_id, "some:id"}
      assert Cypher.query_to_cypher(query) == " WHERE v.id = 'some:id'"
    end

    test "equality on field" do
      query = {:==, {:field, :app}, :my_app}
      assert Cypher.query_to_cypher(query) == " WHERE v.prop_app = 'my_app'"
    end

    test "inequality" do
      query = {:!=, :vertex_type, Root}
      assert Cypher.query_to_cypher(query) == " WHERE v.type <> 'Elixir.Clarity.Vertex.Root'"
    end

    test "IN with values" do
      query = {:in, :vertex_type, [Clarity.Vertex.Module, Root]}

      result = Cypher.query_to_cypher(query)
      assert result =~ "v.type IN ["
      assert result =~ "Elixir.Clarity.Vertex.Module"
      assert result =~ "Elixir.Clarity.Vertex.Root"
    end

    test "IN with empty list" do
      query = {:in, :vertex_type, []}
      assert Cypher.query_to_cypher(query) == " WHERE false"
    end

    test "AND combination" do
      query = {:and, {:==, :vertex_type, Clarity.Vertex.Module}, {:==, {:field, :app}, :my_app}}
      result = Cypher.query_to_cypher(query)
      assert result =~ "AND"
      assert result =~ "v.type = 'Elixir.Clarity.Vertex.Module'"
      assert result =~ "v.prop_app = 'my_app'"
    end

    test "OR combination" do
      query = {:or, {:==, :vertex_type, Clarity.Vertex.Module}, {:==, :vertex_type, Root}}
      result = Cypher.query_to_cypher(query)
      assert result =~ "OR"
    end

    test "NOT" do
      query = {:not, {:==, :vertex_type, Root}}
      result = Cypher.query_to_cypher(query)
      assert result =~ "NOT"
    end

    test "custom variable name" do
      query = {:==, :vertex_id, "test"}
      assert Cypher.query_to_cypher(query, "n") == " WHERE n.id = 'test'"
    end

    test "escapes single quotes" do
      query = {:==, :vertex_id, "it's a test"}
      result = Cypher.query_to_cypher(query)
      assert result =~ "it\\'s a test"
    end

    test "integer values" do
      query = {:==, {:field, :count}, 42}
      assert Cypher.query_to_cypher(query) == " WHERE v.prop_count = 42"
    end
  end

  describe "serialize_vertex/3 and deserialize_vertex/1" do
    test "round-trips a vertex struct" do
      vertex = %Clarity.Vertex.Application{app: :my_app, description: "Test", version: "1.0.0"}

      props = Cypher.serialize_vertex("app:my_app", Clarity.Vertex.Application, vertex)

      assert props["id"] == "app:my_app"
      assert props["type"] == "Elixir.Clarity.Vertex.Application"
      assert is_binary(props["data"])
      assert props["prop_app"] == "my_app"
      assert props["prop_description"] == "Test"

      deserialized = Cypher.deserialize_vertex(props)
      assert deserialized == vertex
    end

    test "promotes queryable fields" do
      vertex = %Clarity.Vertex.Module{module: MyApp.Foo}

      props = Cypher.serialize_vertex("mod:MyApp.Foo", Clarity.Vertex.Module, vertex)

      assert props["prop_module"] == "Elixir.MyApp.Foo"
    end

    test "promotes all simple-typed fields" do
      vertex = %Clarity.Vertex.Application{app: :my_app, description: "Test", version: "1.0.0"}

      props = Cypher.serialize_vertex("app:my_app", Clarity.Vertex.Application, vertex)

      assert props["prop_app"] == "my_app"
      assert props["prop_description"] == "Test"
      assert props["prop_version"] == "1.0.0"
    end

    test "skips nil field values" do
      vertex = %Root{}

      props = Cypher.serialize_vertex("root", Root, vertex)

      refute Map.has_key?(props, "prop_app")
      refute Map.has_key?(props, "prop_module")
    end

    test "promotes boolean fields" do
      vertex = %Clarity.Vertex.Module{module: MyApp.Foo, behaviour?: true}

      props = Cypher.serialize_vertex("mod:MyApp.Foo", Clarity.Vertex.Module, vertex)

      assert props["prop_module"] == "Elixir.MyApp.Foo"
      assert props["prop_behaviour?"] == "true"
    end
  end

  describe "escape_cypher_string/1" do
    test "escapes backslashes" do
      assert Cypher.escape_cypher_string("a\\b") == "a\\\\b"
    end

    test "escapes single quotes" do
      assert Cypher.escape_cypher_string("it's") == "it\\'s"
    end

    test "handles clean strings" do
      assert Cypher.escape_cypher_string("hello") == "hello"
    end
  end
end
