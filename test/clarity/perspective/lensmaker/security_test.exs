defmodule Clarity.Perspective.Lensmaker.SecurityTest do
  # async: false — one test installs the globally-named Clarity.Dependency.Registry
  # ETS table, which must not race with concurrent tests reading it via the lens.
  use ExUnit.Case, async: false

  alias Clarity.Graph
  alias Clarity.Perspective.Lens
  alias Clarity.Perspective.Lensmaker.Security
  alias Clarity.Vertex
  alias Clarity.Vertex.Root
  alias Phoenix.LiveView.Rendered

  setup do
    graph = Graph.new()
    {:ok, graph: graph}
  end

  describe "filter/1" do
    test "keeps applications that carry a security advisory, drops plain libraries",
         %{graph: graph} do
      root = %Root{}
      plain = %Vertex.Application{app: :plain_lib, description: "Plain", version: "1.0.0"}
      advised = %Vertex.Application{app: :mdex, description: "mdex", version: "0.13.1"}
      advisory = %Vertex.Advisory{advisory: %Clarity.Advisory{id: "GHSA-x", package: "mdex"}}

      Graph.add_vertex(graph, plain, root)
      Graph.add_vertex(graph, advised, root)
      Graph.add_vertex(graph, advisory, advised)
      Graph.add_edge(graph, root, plain, :application)
      Graph.add_edge(graph, root, advised, :application)
      Graph.add_edge(graph, advised, advisory, :advisory)

      query = Security.make_lens().filter.(graph)
      visible = Graph.vertices(graph, query)

      assert advised in visible
      assert advisory in visible
      refute plain in visible
    end

    test "keeps outdated applications visible, drops up-to-date ones", %{graph: graph} do
      :ets.new(Clarity.Dependency.Registry, [:named_table, :set, :public])
      :ets.insert(Clarity.Dependency.Registry, {{:package, "stale"}, %{latest: "2.0.0", retired: []}})
      :ets.insert(Clarity.Dependency.Registry, {{:package, "fresh"}, %{latest: "1.0.0", retired: []}})

      root = %Root{}
      stale = %Vertex.Application{app: :stale, description: "Stale", version: "1.0.0"}
      fresh = %Vertex.Application{app: :fresh, description: "Fresh", version: "1.0.0"}

      Graph.add_vertex(graph, stale, root)
      Graph.add_vertex(graph, fresh, root)
      Graph.add_edge(graph, root, stale, :application)
      Graph.add_edge(graph, root, fresh, :application)

      query = Security.make_lens().filter.(graph)
      visible = Graph.vertices(graph, query)

      assert stale in visible
      refute fresh in visible
    end
  end

  describe "make_lens/0" do
    test "creates security lens with correct properties" do
      assert %Lens{
               id: "security",
               name: "Security",
               description: description,
               icon: icon_fn,
               filter: filter,
               content_sorter: content_sorter
             } = Security.make_lens()

      assert is_binary(description)
      assert is_function(icon_fn, 0)
      assert is_function(filter, 1)
      assert is_function(content_sorter, 2)
    end

    test "security lens focuses on security-related elements" do
      lens = Security.make_lens()

      assert is_function(lens.filter, 1)
    end

    test "security lens icon renders shield emoji" do
      lens = Security.make_lens()

      rendered = lens.icon.()
      assert %Rendered{} = rendered
    end

    test "security lens uses default alphabetical content sorter" do
      lens = Security.make_lens()

      # Should use the default sorter function
      assert lens.content_sorter == (&Lens.sort_alphabetically/2)

      # Create test content (using the Registry.Content struct)
      content_a = %Clarity.Content{
        id: "content_a",
        name: "Content A",
        provider: __MODULE__,
        live_view?: false,
        live_component?: false
      }

      content_z = %Clarity.Content{
        id: "content_z",
        name: "Content Z",
        provider: __MODULE__,
        live_view?: false,
        live_component?: false
      }

      content_b = %Clarity.Content{
        id: "content_b",
        name: "Content B",
        provider: __MODULE__,
        live_view?: false,
        live_component?: false
      }

      # Test alphabetical sorting using the default function
      assert Lens.sort_alphabetically(content_a, content_z) == true
      assert Lens.sort_alphabetically(content_z, content_a) == false
      assert Lens.sort_alphabetically(content_a, content_b) == true
      assert Lens.sort_alphabetically(content_b, content_a) == false
    end
  end
end
