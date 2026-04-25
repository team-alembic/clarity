defmodule Clarity.Content.Ash.ApplicationDiagramTest do
  use ExUnit.Case, async: true

  alias Clarity.Content.Ash.ApplicationDiagram
  alias Clarity.Vertex.Application
  alias Clarity.Vertex.Root

  describe inspect(&ApplicationDiagram.name/0) do
    test "returns application diagram name" do
      assert ApplicationDiagram.name() == "Application Diagram"
    end
  end

  describe inspect(&ApplicationDiagram.description/0) do
    test "returns application diagram description" do
      assert ApplicationDiagram.description() ==
               "Visual map of all Ash resources, grouped by domain"
    end
  end

  describe inspect(&ApplicationDiagram.applies?/2) do
    test "returns true for Application vertex with Ash domains" do
      vertex = %Application{app: :clarity, description: nil, version: "0.2.0"}
      assert ApplicationDiagram.applies?(vertex, nil)
    end

    test "returns false for Application vertex without Ash domains" do
      vertex = %Application{app: :kernel, description: nil, version: "10.1"}
      refute ApplicationDiagram.applies?(vertex, nil)
    end

    test "returns false for non-Application vertices" do
      refute ApplicationDiagram.applies?(%Root{}, nil)
    end
  end

  describe inspect(&ApplicationDiagram.render_static/2) do
    test "returns viz tuple with function" do
      vertex = %Application{app: :clarity, description: nil, version: "0.2.0"}

      assert {:viz, viz_fn} = ApplicationDiagram.render_static(vertex, nil)
      assert is_function(viz_fn, 1)
    end

    test "generated DOT contains digraph header" do
      vertex = %Application{app: :clarity, description: nil, version: "0.2.0"}
      {:viz, viz_fn} = ApplicationDiagram.render_static(vertex, nil)

      dot = IO.iodata_to_binary(viz_fn.(%{theme: :light, zoom_subgraph: nil}))

      assert dot =~ "digraph {"
      assert dot =~ "rankdir = LR;"
    end

    test "DOT places resources inside a domain cluster" do
      vertex = %Application{app: :clarity, description: nil, version: "0.2.0"}
      {:viz, viz_fn} = ApplicationDiagram.render_static(vertex, nil)

      dot = IO.iodata_to_binary(viz_fn.(%{theme: :light, zoom_subgraph: nil}))

      assert dot =~ "subgraph cluster_dom_Demo_Accounts_Domain"
      assert dot =~ ~s|label = "Demo.Accounts.Domain"|
      assert dot =~ ~s|label="User"|
    end

    test "resource nodes link to their vertex IDs" do
      vertex = %Application{app: :clarity, description: nil, version: "0.2.0"}
      {:viz, viz_fn} = ApplicationDiagram.render_static(vertex, nil)

      dot = IO.iodata_to_binary(viz_fn.(%{theme: :light, zoom_subgraph: nil}))

      assert dot =~ ~s|URL="#ash-resource:demo-accounts-user"|
    end

    test "dark theme uses dark-palette colours" do
      vertex = %Application{app: :clarity, description: nil, version: "0.2.0"}
      {:viz, viz_fn} = ApplicationDiagram.render_static(vertex, nil)

      light = IO.iodata_to_binary(viz_fn.(%{theme: :light, zoom_subgraph: nil}))
      dark = IO.iodata_to_binary(viz_fn.(%{theme: :dark, zoom_subgraph: nil}))

      refute light == dark
      # Light cluster fill from the palette
      assert light =~ "fillcolor = \"#fde68a\""
      # Dark cluster fill from the palette
      assert dark =~ "fillcolor = \"#78350f\""
    end
  end

  describe "live_component rendering" do
    import Phoenix.LiveViewTest

    test "default mode is :cluster and renders both toggle buttons" do
      vertex = %Application{app: :clarity, description: nil, version: "0.2.0"}

      html =
        render_component(ApplicationDiagram,
          id: "test",
          vertex: vertex,
          lens: nil,
          theme: :light
        )

      assert html =~ "Grouped"
      assert html =~ "Coloured"
      assert html =~ "subgraph cluster_dom_Demo_Accounts_Domain"
      # Cluster button should be the active (pressed) one by default
      assert html =~ ~s|aria-pressed="true"|
    end
  end
end
