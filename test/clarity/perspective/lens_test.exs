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

  describe "show_vertex_types function" do
    test "show_vertex_types returns all types by default" do
      lens = %Lens{
        id: "test",
        name: "Test",
        icon: fn ->
          assigns = %{}
          ~H"🔍"
        end,
        filter: true
      }

      assert lens.show_vertex_types == (&Lens.default_show_vertex_types/1)
    end

    test "default_show_vertex_types returns all input types unchanged" do
      types = [Clarity.Vertex.Application, Clarity.Vertex.Module]
      assert Lens.default_show_vertex_types(types) == types
    end

    test "show_vertex_types can be customized" do
      custom_filter = fn types ->
        Enum.reject(types, &(&1 == Clarity.Vertex.Application))
      end

      lens = %Lens{
        id: "test",
        name: "Test",
        icon: fn ->
          assigns = %{}
          ~H"🔍"
        end,
        filter: true,
        show_vertex_types: custom_filter
      }

      types = [Clarity.Vertex.Application, Clarity.Vertex.Module]
      assert lens.show_vertex_types.(types) == [Clarity.Vertex.Module]
    end
  end
end
