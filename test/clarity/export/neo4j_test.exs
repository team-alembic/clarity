defmodule Clarity.Export.Neo4jTest do
  use ExUnit.Case, async: true

  alias Clarity.Export.Neo4j
  alias Clarity.Test.Helper

  test "exports the graph in batched neo4j requests" do
    parent = self()
    clarity = Helper.build_test_clarity()

    request_fun = fn _req, options ->
      send(parent, {:request, options})
      {:ok, %{status: 200, body: %{"results" => [], "errors" => []}}}
    end

    assert {:ok, %{vertices: 3, edges: 2, requests: 5}} =
             Neo4j.export(
               clarity.graph,
               req: :fake,
               request_fun: request_fun,
               database: "clarity",
               chunk_size: 2,
               clear: true
             )

    assert_receive {:request, [url: "/db/clarity/tx/commit", json: %{"statements" => [statement]}]}
    assert statement["statement"] =~ "CREATE CONSTRAINT"

    assert_receive {:request, [url: "/db/clarity/tx/commit", json: %{"statements" => [statement]}]}
    assert statement["statement"] =~ "DETACH DELETE"

    assert_receive {:request, [url: "/db/clarity/tx/commit", json: %{"statements" => [statement]}]}
    assert statement["statement"] =~ "UNWIND $batch AS row"
    assert length(statement["parameters"]["batch"]) == 2

    assert_receive {:request, [url: "/db/clarity/tx/commit", json: %{"statements" => [statement]}]}
    assert statement["statement"] =~ "SET v = row"
    assert length(statement["parameters"]["batch"]) == 1

    assert_receive {:request, [url: "/db/clarity/tx/commit", json: %{"statements" => [statement]}]}
    assert statement["statement"] =~ "MERGE (a)-[:EDGE"
    assert length(statement["parameters"]["batch"]) == 2
  end

  test "raises when neo4j returns errors in a 200 response" do
    clarity = Helper.build_test_clarity()

    request_fun = fn _req, _options ->
      {:ok,
       %{
         status: 200,
         body: %{
           "results" => [],
           "errors" => [%{"code" => "Neo.ClientError.Statement.TypeError", "message" => "bad type"}]
         }
       }}
    end

    assert_raise RuntimeError, ~r/Neo4j export error/, fn ->
      Neo4j.export(clarity.graph, req: :fake, request_fun: request_fun, database: "clarity")
    end
  end
end
