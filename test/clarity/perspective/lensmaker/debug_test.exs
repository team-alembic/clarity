defmodule Clarity.Perspective.Lensmaker.DebugTest do
  use ExUnit.Case, async: true

  alias Clarity.Graph
  alias Clarity.Perspective.Lens
  alias Clarity.Perspective.Lensmaker.Debug
  alias Clarity.Vertex.Root
  alias Phoenix.LiveView.Rendered

  setup do
    graph = Graph.new()
    {:ok, graph: graph}
  end

  describe "make_lens/0" do
    test "creates debug lens with correct properties" do
      assert %Lens{
               id: "debug",
               name: "Debug",
               description: description,
               icon: icon_fn,
               filter: filter,
               content_sorter: content_sorter,
               intro_vertex: intro_vertex_fn
             } = Debug.make_lens()

      assert is_binary(description)
      assert is_function(icon_fn, 0)
      assert is_function(filter, 1)
      assert is_function(content_sorter, 2)
      assert is_function(intro_vertex_fn, 1)
    end

    test "debug lens shows everything (no filtering)" do
      lens = Debug.make_lens()

      # Debug filter should always return true (show everything)
      assert lens.filter.(%Root{})
      assert lens.filter.(%{some: "vertex"})
      assert lens.filter.(nil)
    end

    test "debug lens uses root as intro vertex" do
      lens = Debug.make_lens()
      graph = Graph.new()

      assert %Root{} = lens.intro_vertex.(graph)
    end

    test "debug lens icon renders bug emoji" do
      lens = Debug.make_lens()

      rendered = lens.icon.()
      assert %Rendered{} = rendered
    end

    test "debug lens content sorter prioritizes graph first, then alphabetical" do
      lens = Debug.make_lens()

      # Create test content
      graph_content = %Clarity.Content{
        id: "Clarity.Content.Graph",
        name: "Graph",
        provider: __MODULE__,
        live_view?: false
      }

      content_a = %Clarity.Content{
        id: "content_a",
        name: "Content A",
        provider: __MODULE__,
        live_view?: false
      }

      content_z = %Clarity.Content{
        id: "content_z",
        name: "Content Z",
        provider: __MODULE__,
        live_view?: false
      }

      content_b = %Clarity.Content{
        id: "content_b",
        name: "Content B",
        provider: __MODULE__,
        live_view?: false
      }

      # Test graph should come first
      assert lens.content_sorter.(graph_content, content_a) == true
      assert lens.content_sorter.(content_a, graph_content) == false

      # Test alphabetical sorting for non-graph content
      assert lens.content_sorter.(content_a, content_z) == true
      assert lens.content_sorter.(content_z, content_a) == false
      assert lens.content_sorter.(content_a, content_b) == true
      assert lens.content_sorter.(content_b, content_a) == false
    end
  end
end
