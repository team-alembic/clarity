defmodule Clarity.Graph.MemoTest do
  use ExUnit.Case, async: true

  alias Clarity.Graph
  alias Clarity.Graph.Memo
  alias Clarity.Vertex

  describe inspect(&Memo.fetch/3) do
    test "works a result out once while the graph stays the same" do
      graph = Graph.new()

      assert Memo.fetch(graph, :key, fn -> make_ref() end) ==
               Memo.fetch(graph, :key, fn -> make_ref() end)
    end

    test "works it out again once the graph changes" do
      graph = Graph.new()
      first = Memo.fetch(graph, :key, fn -> make_ref() end)

      :ok = Graph.add_vertex(graph, %Vertex.Module{module: Enum}, %Vertex.Root{})

      refute Memo.fetch(graph, :key, fn -> make_ref() end) == first
    end

    test "keeps results apart by key, graph and view" do
      graph = Graph.new()
      :ok = Graph.add_vertex(graph, %Vertex.Module{module: Enum}, %Vertex.Root{})
      view = Graph.filter(graph, {:==, :vertex_type, Vertex.Root})

      results = [
        Memo.fetch(graph, :key, fn -> make_ref() end),
        Memo.fetch(graph, :other, fn -> make_ref() end),
        Memo.fetch(Graph.new(), :key, fn -> make_ref() end),
        Memo.fetch(view, :key, fn -> make_ref() end)
      ]

      assert results == Enum.uniq(results)
    end
  end
end
