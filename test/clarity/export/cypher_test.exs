defmodule Clarity.Export.CypherTest do
  use ExUnit.Case, async: true

  alias Clarity.Export.Cypher
  alias Clarity.Vertex

  defmodule BigIntegerVertex do
    @moduledoc false
    @enforce_keys [:name, :hash]
    defstruct [:name, :hash]

    defimpl Clarity.Vertex do
      alias Clarity.Vertex.Util

      @impl Vertex
      def id(%@for{name: name}), do: Util.id(@for, [name, "110290880181768203941514442314913379524"])

      @impl Vertex
      def type_label(_vertex), do: "BigInteger"

      @impl Vertex
      def name(%@for{name: name}), do: name
    end
  end

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

  test "stringifies promoted integers outside neo4j's 64-bit range" do
    vertex = %BigIntegerVertex{name: "iter-into-iterable", hash: 110_290_880_181_768_203_941_514_442_314_913_379_524}

    props = Cypher.serialize_vertex(vertex)

    assert props["id"] =~ ":iter-into-iterable:110290880181768203941514442314913379524"
    assert props["prop_hash"] == "110290880181768203941514442314913379524"
  end
end
