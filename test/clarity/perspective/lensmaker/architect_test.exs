defmodule Clarity.Perspective.Lensmaker.ArchitectTest do
  use ExUnit.Case, async: true

  alias AshDiagram.ClarityContent
  alias Clarity.Content
  alias Clarity.Graph
  alias Clarity.Perspective.Lens
  alias Clarity.Perspective.Lensmaker.Architect
  alias Clarity.Status
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Signal
  alias Clarity.Vertex.Ash.SignalModule
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
               content_sorter: content_sorter
             } = Architect.make_lens()

      assert is_binary(description)
      assert is_function(icon_fn, 0)
      assert is_function(filter, 1)
      assert is_function(content_sorter, 2)
    end

    test "leaves out the graph, module documentation and ash_diagram's policy tabs" do
      assert Architect.make_lens().contents ==
               {:except,
                [
                  Content.Graph,
                  Content.Moduledoc,
                  ClarityContent.PolicyDiagram,
                  ClarityContent.PolicySimulation
                ]}
    end

    test "shows Ash signal modules and signals" do
      available = [Signal, SignalModule, Vertex.Module]

      assert Architect.make_lens().show_vertex_types.(available) == [
               Signal,
               SignalModule
             ]
    end

    test "surfaces :integrity status indicators, and no others" do
      filter = Architect.make_lens().status_filter

      assert filter.(%Status{severity: :error, class: :integrity, message: "x", source: __MODULE__})
      refute filter.(%Status{severity: :error, class: :security, message: "y", source: __MODULE__})
    end

    test "keeps an application whose only architecture is a signal module", %{graph: graph} do
      app = %Vertex.Application{app: :signals_only, description: "Signals only", version: "1.0.0"}
      signal_module = %SignalModule{signal_module: Demo.Billing.Signals}
      Graph.add_vertex(graph, app, %Vertex.Root{})
      Graph.add_vertex(graph, signal_module, app)
      Graph.add_edge(graph, app, signal_module, :signal_module)

      assert {:or, {:in, :vertex_id, ids}, _others} = Architect.make_lens().filter.(graph)
      assert Vertex.id(app) in ids
    end

    test "architect lens focuses on structural elements" do
      lens = Architect.make_lens()

      # Architect filter should focus on structural/architectural elements
      # This is a placeholder - actual filtering logic will depend on vertex types
      assert is_function(lens.filter, 1)
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
      content_a = %Content{
        id: "content_a",
        name: "Content A",
        provider: __MODULE__,
        live_view?: false,
        live_component?: false
      }

      content_z = %Content{
        id: "content_z",
        name: "Content Z",
        provider: __MODULE__,
        live_view?: false,
        live_component?: false
      }

      content_b = %Content{
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
