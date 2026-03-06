defmodule Clarity.Export.ArcadeDBTest do
  use ExUnit.Case, async: true

  alias Clarity.Export.ArcadeDB
  alias Clarity.Test.Helper

  test "exports the graph in batched arcadedb requests" do
    parent = self()
    clarity = Helper.build_test_clarity()

    request_fun = fn _req, options ->
      send(parent, {:request, options})
      {:ok, %{status: 200}}
    end

    assert {:ok, %{vertices: 3, edges: 2, requests: 6}} =
             ArcadeDB.export(
               clarity.graph,
               req: :fake,
               request_fun: request_fun,
               database: "clarity",
               chunk_size: 2,
               clear: true
             )

    assert_receive {:request, [url: "/api/v1/command/clarity", json: %{"command" => command}]}
    assert command =~ "CREATE VERTEX TYPE Vertex"

    assert_receive {:request, [url: "/api/v1/command/clarity", json: %{"command" => command}]}
    assert command =~ "CREATE EDGE TYPE EDGE"

    assert_receive {:request, [url: "/api/v1/command/clarity", json: %{"command" => command}]}
    assert command =~ "DETACH DELETE"

    assert_receive {:request, [url: "/api/v1/batch/clarity", json: %{"operations" => [operation]}]}
    assert operation["command"] =~ "UNWIND $batch AS row"
    assert length(operation["params"]["batch"]) == 2

    assert_receive {:request, [url: "/api/v1/batch/clarity", json: %{"operations" => [operation]}]}
    assert operation["command"] =~ "SET v = row"
    assert length(operation["params"]["batch"]) == 1

    assert_receive {:request, [url: "/api/v1/batch/clarity", json: %{"operations" => [operation]}]}
    assert operation["command"] =~ "MERGE (a)-[:EDGE"
    assert length(operation["params"]["batch"]) == 2
  end
end
