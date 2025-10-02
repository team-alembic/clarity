defmodule Clarity.Content.GraphTest do
  use ExUnit.Case, async: true

  alias Clarity.Content.Graph
  alias Clarity.Perspective.Lens
  alias Clarity.Vertex.Root

  describe inspect(&Graph.name/0) do
    test "returns graph navigation name" do
      assert Graph.name() == "Graph Navigation"
    end
  end

  describe inspect(&Graph.description/0) do
    test "returns graph navigation description" do
      assert Graph.description() == "Visual graph navigation and exploration"
    end
  end

  describe inspect(&Graph.applies?/2) do
    test "returns true for all vertices" do
      vertex = %Root{}

      lens = %Lens{
        id: "test",
        name: "Test",
        description: "Test lens",
        icon: fn -> nil end,
        filter: fn _ -> true end,
        intro_vertex: fn _ -> %Root{} end
      }

      assert Graph.applies?(vertex, lens) == true
    end

    test "returns true regardless of lens" do
      vertex = %Root{}
      assert Graph.applies?(vertex, nil) == true
    end
  end

  describe inspect(&Graph.render_static/2) do
    test "returns viz tuple with function" do
      vertex = %Root{}

      lens = %Lens{
        id: "test",
        name: "Test",
        description: "Test lens",
        icon: fn -> nil end,
        filter: fn _ -> true end,
        intro_vertex: fn _ -> %Root{} end
      }

      assert {:viz, viz_fn} = Graph.render_static(vertex, lens)
      assert is_function(viz_fn, 1)
    end

    test "viz function accepts context and returns DOT output" do
      {:viz, viz_fn} = Graph.render_static(%Root{}, nil)

      graph = Clarity.Graph.new()
      Clarity.Graph.add_vertex(graph, %Root{}, %Root{})

      props = %{
        theme: :light,
        zoom_subgraph: graph
      }

      dot_output = viz_fn.(props)

      assert is_binary(IO.iodata_to_binary(dot_output))
      assert IO.iodata_to_binary(dot_output) =~ "digraph"
    end

    test "viz function supports dark theme" do
      {:viz, viz_fn} = Graph.render_static(%Root{}, nil)

      graph = Clarity.Graph.new()

      props = %{
        theme: :dark,
        zoom_subgraph: graph
      }

      dot_output = viz_fn.(props)
      dot_string = IO.iodata_to_binary(dot_output)

      assert dot_string =~ "digraph"
      assert dot_string =~ "#9ca3af"
    end
  end
end
