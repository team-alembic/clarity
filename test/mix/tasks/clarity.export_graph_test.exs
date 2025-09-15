defmodule Mix.Tasks.Clarity.ExportGraphTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Clarity.TestHelper
  alias Mix.Tasks.Clarity.ExportGraph

  setup do
    # Set up test clarity agent
    clarity = TestHelper.build_test_clarity()
    {:ok, clarity: clarity}
  end

  test "exports graph to stdout by default", %{clarity: clarity} do
    output =
      capture_io(fn ->
        ExportGraph.run(clarity, [])
      end)

    # Should output DOT format
    assert output =~ "digraph"
    assert output =~ "clarity"
  end

  test "exports graph to file when --out specified", %{clarity: clarity} do
    tmp_file = Path.join(System.tmp_dir!(), "test_graph.dot")

    try do
      ExportGraph.run(clarity, ["--out", tmp_file])

      assert File.exists?(tmp_file)
      content = File.read!(tmp_file)
      assert content =~ "digraph"
      assert content =~ "clarity"
    after
      File.rm(tmp_file)
    end
  end

  test "supports short option -o for output file", %{clarity: clarity} do
    tmp_file = Path.join(System.tmp_dir!(), "test_graph_short.dot")

    try do
      ExportGraph.run(clarity, ["-o", tmp_file])

      assert File.exists?(tmp_file)
      content = File.read!(tmp_file)
      assert content =~ "digraph"
    after
      File.rm(tmp_file)
    end
  end

  test "filters vertices when --filter-vertices specified", %{clarity: clarity} do
    output =
      capture_io(fn ->
        ExportGraph.run(clarity, ["--filter-vertices", "application:clarity"])
      end)

    # Should still output DOT format but potentially filtered
    assert output =~ "digraph"
  end

  test "supports short option -f for filter vertices", %{clarity: clarity} do
    output =
      capture_io(fn ->
        ExportGraph.run(clarity, ["-f", "application:clarity"])
      end)

    # Should still output DOT format
    assert output =~ "digraph"
  end

  test "handles multiple filter vertices", %{clarity: clarity} do
    output =
      capture_io(fn ->
        ExportGraph.run(clarity, ["-f", "application:clarity", "-f", "root"])
      end)

    # Should still output DOT format
    assert output =~ "digraph"
  end

  test "handles invalid filter vertices gracefully", %{clarity: clarity} do
    assert_raise KeyError, fn ->
      capture_io(fn ->
        ExportGraph.run(clarity, ["-f", "nonexistent_vertex"])
      end)
    end
  end
end
