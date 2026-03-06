defmodule Mix.Tasks.Clarity.ExportGraphDbTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Clarity.Export.Neo4j
  alias Clarity.Test.Helper
  alias Mix.Tasks.Clarity.ExportGraphDb

  setup do
    clarity = Helper.build_test_clarity()

    on_exit(fn ->
      Application.delete_env(:clarity, Neo4j)
    end)

    {:ok, clarity: clarity}
  end

  test "exports via the selected target and prints a summary", %{clarity: clarity} do
    parent = self()

    Application.put_env(
      :clarity,
      Neo4j,
      req: :fake,
      request_fun: fn _req, options ->
        send(parent, {:request, options})
        {:ok, %{status: 200}}
      end,
      database: "clarity"
    )

    output =
      capture_io(fn ->
        assert {:ok, %{vertices: 3, edges: 2, requests: 3}} =
                 ExportGraphDb.run(clarity, ["--target", "neo4j"])
      end)

    assert output =~ "Exported 3 vertices and 2 edges to neo4j in 3 requests"
    assert_receive {:request, _}
  end

  test "raises for unsupported targets", %{clarity: clarity} do
    assert_raise ArgumentError, ~r/unsupported --target/, fn ->
      ExportGraphDb.run(clarity, ["--target", "janusgraph"])
    end
  end
end
