defmodule Clarity.Perspective.LensTest do
  use ExUnit.Case, async: true

  import Phoenix.Component

  alias Clarity.Graph
  alias Clarity.Perspective.Lens

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
        filter: true
      }

      result = lens.icon.()
      assert %Phoenix.LiveView.Rendered{} = result
    end
  end

  describe "filter integration" do
    test "filter function works with Graph.filter/2" do
      graph = Graph.new()
      filter_fn = true

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
        filter: true
      }

      # Should use default alphabetical sorter
      assert lens.content_sorter == (&Lens.sort_alphabetically/2)
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
        filter: true,
        content_sorter: custom_sorter
      }

      assert lens.content_sorter == custom_sorter
    end
  end
end
