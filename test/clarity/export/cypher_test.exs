defmodule Clarity.Export.CypherTest do
  use ExUnit.Case, async: true

  alias Clarity.Export.Cypher
  alias Clarity.Vertex

  test "serializes vertices with graph metadata and promoted fields" do
    vertex = %Vertex.Application{
      app: :clarity,
      description: "Clarity App",
      version: "0.4.0"
    }

    props = Cypher.serialize_vertex(vertex)

    assert props["id"] == "application:clarity"
    assert props["type"] == "Elixir.Clarity.Vertex.Application"
    assert props["type_label"] == "Application"
    assert props["name"] == "clarity"
    assert is_binary(props["data"])
    assert props["prop_app"] == "clarity"
    assert props["prop_description"] == "Clarity App"
    assert props["prop_version"] == "0.4.0"
  end

  test "serializes edges from graph edge tuples" do
    edge =
      {:"$e", %Vertex.Root{}, %Vertex.Application{app: :clarity, description: nil, version: nil}, :child}

    assert Cypher.serialize_edge(edge) == %{
             "from_id" => "root",
             "to_id" => "application:clarity",
             "label" => "child"
           }
  end

  test "escapes cypher strings" do
    assert Cypher.escape_cypher_string("it's\\fine") == "it\\'s\\\\fine"
  end
end
