defmodule Clarity.Perspective.LensTest do
  use ExUnit.Case, async: true

  import Phoenix.Component

  alias Clarity.Graph
  alias Clarity.Graph.Filter
  alias Clarity.Perspective.Lens
  alias Clarity.Vertex.Root

  describe "struct creation" do
    test "creates valid lens with all required fields" do
      icon_fn = fn ->
        assigns = %{}
        ~H"🐛"
      end

      intro_vertex_fn = fn _graph -> %Root{} end
      filter_fn = Filter.custom(fn _vertex -> true end)

      content_sorter = fn a, b -> a.id <= b.id end

      assert %Lens{
               id: "test",
               name: "Test Lens",
               description: "A test lens",
               icon: ^icon_fn,
               filter: ^filter_fn,
               content_sorter: ^content_sorter,
               intro_vertex: ^intro_vertex_fn
             } = %Lens{
               id: "test",
               name: "Test Lens",
               description: "A test lens",
               icon: icon_fn,
               filter: filter_fn,
               content_sorter: content_sorter,
               intro_vertex: intro_vertex_fn
             }
    end

    test "creates lens with minimal required fields" do
      icon_fn = fn ->
        assigns = %{}
        ~H"🐛"
      end

      intro_vertex_fn = fn _graph -> %Root{} end
      filter_fn = Filter.custom(fn _vertex -> true end)

      content_sorter = fn a, b -> a.id <= b.id end

      assert %Lens{
               id: "minimal",
               name: "Minimal",
               description: nil,
               icon: ^icon_fn,
               filter: ^filter_fn,
               content_sorter: ^content_sorter,
               intro_vertex: ^intro_vertex_fn
             } = %Lens{
               id: "minimal",
               name: "Minimal",
               icon: icon_fn,
               filter: filter_fn,
               content_sorter: content_sorter,
               intro_vertex: intro_vertex_fn
             }
    end
  end

  describe "icon function" do
    test "icon function returns rendered component" do
      icon_fn = fn ->
        assigns = %{}
        ~H"🔍"
      end

      lens = %Lens{
        id: "test",
        name: "Test",
        icon: icon_fn,
        filter: Filter.custom(fn _vertex -> true end)
      }

      result = lens.icon.()
      assert %Phoenix.LiveView.Rendered{} = result
    end
  end

  describe "intro_vertex function" do
    test "intro_vertex function returns vertex based on graph" do
      graph = Graph.new()

      intro_vertex_fn = fn g ->
        assert g == graph
        %Root{}
      end

      lens = %Lens{
        id: "test",
        name: "Test",
        icon: fn ->
          assigns = %{}
          ~H"🔍"
        end,
        filter: Filter.custom(fn _vertex -> true end),
        intro_vertex: intro_vertex_fn
      }

      assert %Root{} = lens.intro_vertex.(graph)
    end

    test "intro_vertex function can return nil" do
      intro_vertex_fn = fn _graph -> nil end

      lens = %Lens{
        id: "test",
        name: "Test",
        icon: fn ->
          assigns = %{}
          ~H"🔍"
        end,
        filter: Filter.custom(fn _vertex -> true end),
        intro_vertex: intro_vertex_fn
      }

      assert nil == lens.intro_vertex.(Graph.new())
    end
  end

  describe "filter integration" do
    test "filter function works with Graph.filter/2" do
      graph = Graph.new()
      filter_fn = Filter.custom(fn _vertex -> true end)

      lens = %Lens{
        id: "test",
        name: "Test",
        icon: fn ->
          assigns = %{}
          ~H"🔍"
        end,
        filter: filter_fn
      }

      filtered_graph = Graph.filter(graph, lens.filter)
      assert %Graph{} = filtered_graph
      Graph.delete(filtered_graph)
    end
  end

  describe "content_sorter function" do
    test "content_sorter sorts content alphabetically by default" do
      lens = %Lens{
        id: "test",
        name: "Test",
        icon: fn ->
          assigns = %{}
          ~H"🔍"
        end,
        filter: Filter.custom(fn _vertex -> true end)
      }

      # Should use default alphabetical sorter
      assert lens.content_sorter == (&Lens.sort_alphabetically_by_id/2)
    end

    test "content_sorter can be customized" do
      custom_sorter = fn a, b -> a.id >= b.id end

      lens = %Lens{
        id: "test",
        name: "Test",
        icon: fn ->
          assigns = %{}
          ~H"🔍"
        end,
        filter: Filter.custom(fn _vertex -> true end),
        content_sorter: custom_sorter
      }

      assert lens.content_sorter == custom_sorter
    end
  end
end
