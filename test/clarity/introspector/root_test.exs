defmodule Clarity.Introspector.RootTest do
  use ExUnit.Case, async: true

  alias Clarity.Introspector.Root
  alias Clarity.Vertex

  describe inspect(&Root.introspect/1) do
    test "adds a root vertex to the graph" do
      graph = :digraph.new()

      result_graph = Root.introspect(graph)

      assert result_graph == graph
      vertices = :digraph.vertices(graph)
      assert length(vertices) == 1

      [root_vertex] = vertices
      assert %Vertex.Root{} = root_vertex
    end

    test "returns the same graph instance" do
      graph = :digraph.new()

      result = Root.introspect(graph)

      assert result == graph
    end
  end
end
