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

  describe "sort_alphabetically/2" do
    alias Clarity.Content

    defp content(name, opts \\ []) do
      id = Keyword.get(opts, :id, name)
      priority = Keyword.get(opts, :sort_priority, 0)

      %Content{
        id: id,
        name: name,
        provider: __MODULE__,
        live_view?: false,
        live_component?: false,
        sort_priority: priority
      }
    end

    test "sorts by sort_priority first (lower values first)" do
      high = content("Z Content", sort_priority: -100)
      low = content("A Content", sort_priority: 100)
      mid = content("M Content", sort_priority: 0)

      sorted = Enum.sort([low, mid, high], &Lens.sort_alphabetically/2)

      assert [^high, ^mid, ^low] = sorted
    end

    test "sorts alphabetically by name within same priority" do
      z = content("Z Content")
      a = content("A Content")
      m = content("M Content")

      sorted = Enum.sort([z, a, m], &Lens.sort_alphabetically/2)

      assert [^a, ^m, ^z] = sorted
    end

    test "breaks ties by id for deterministic ordering" do
      first = content("Same Name", id: "aaa")
      second = content("Same Name", id: "zzz")

      sorted = Enum.sort([second, first], &Lens.sort_alphabetically/2)

      assert [^first, ^second] = sorted
    end

    test "overview content sorts before regular content" do
      overview = content("Resource Overview", sort_priority: -100)
      regular = content("Module Documentation")
      graph = content("Graph Navigation", sort_priority: 100)

      sorted = Enum.sort([graph, regular, overview], &Lens.sort_alphabetically/2)

      assert [^overview, ^regular, ^graph] = sorted
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
