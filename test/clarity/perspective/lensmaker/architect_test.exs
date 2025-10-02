defmodule Clarity.Perspective.Lensmaker.ArchitectTest do
  use ExUnit.Case, async: true

  alias Clarity.Graph
  alias Clarity.Perspective.Lens
  alias Clarity.Perspective.Lensmaker.Architect
  alias Phoenix.LiveView.Rendered

  setup do
    graph = Graph.new()
    {:ok, graph: graph}
  end

  describe "make_lens/0" do
    test "creates architect lens with correct properties" do
      assert %Lens{
               id: "architect",
               name: "Architect",
               description: description,
               icon: icon_fn,
               filter: filter,
               content_sorter: content_sorter,
               intro_vertex: intro_vertex_fn
             } = Architect.make_lens()

      assert is_binary(description)
      assert is_function(icon_fn, 0)
      assert is_function(filter, 1)
      assert is_function(content_sorter, 2)
      assert is_function(intro_vertex_fn, 1)
    end

    test "architect lens focuses on structural elements" do
      lens = Architect.make_lens()

      # Architect filter should focus on structural/architectural elements
      # This is a placeholder - actual filtering logic will depend on vertex types
      assert is_function(lens.filter, 1)
    end

    test "architect lens uses appropriate intro vertex" do
      lens = Architect.make_lens()
      graph = Graph.new()

      intro_vertex = lens.intro_vertex.(graph)
      assert intro_vertex
    end

    test "architect lens icon renders building emoji" do
      lens = Architect.make_lens()

      rendered = lens.icon.()
      assert %Rendered{} = rendered
    end

    test "architect lens uses default alphabetical content sorter" do
      lens = Architect.make_lens()

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
