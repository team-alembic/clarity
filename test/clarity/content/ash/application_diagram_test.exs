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

    test "DOT contains digraph header with TB rankdir for top legend" do
      dot = render_dot(:light)

      assert dot =~ "digraph {"
      assert dot =~ "rankdir=TB;"
    end

    test "DOT renders an HTML-table legend before the resource cluster" do
      dot = render_dot(:light)

      legend_pos = dot |> :binary.match("__legend [shape=plaintext") |> elem(0)
      domain_pos = dot |> :binary.match("subgraph cluster_dom_") |> elem(0)
      assert legend_pos < domain_pos
      # Header + colour swatch row signature
      assert dot =~ "<B>DOMAINS</B>"
      assert dot =~ ~s|FIXEDSIZE="TRUE" BGCOLOR="#fef3c7"|
    end

    test "DOT places resources inside a domain cluster (cluster mode)" do
      dot = render_dot(:light)

      assert dot =~ "subgraph cluster_dom_Demo_Accounts"
      assert dot =~ ~s|label="Demo.Accounts"|
      assert dot =~ ~s|label="User"|
    end

    test "uses square boxes (no rounded corners)" do
      dot = render_dot(:light)

      assert dot =~ "shape=box, style=filled"
      refute dot =~ "rounded"
    end

    test "resource nodes link to their vertex IDs" do
      dot = render_dot(:light)

      assert dot =~ ~s|URL="#ash-resource:demo-accounts-user"|
    end

    test "dark theme uses dark-palette colours" do
      light = render_dot(:light)
      dark = render_dot(:dark)

      refute light == dark
      # Light cluster fill from the palette
      assert light =~ ~s|fillcolor="#fef3c7"|
      # Dark cluster fill from the palette
      assert dark =~ ~s|fillcolor="#854d0e"|
    end
  end

  describe "live_component rendering" do
    import Phoenix.LiveViewTest

    test "default mode is :cluster, default legend is :top, both toggle pairs render" do
      vertex = %Application{app: :clarity, description: nil, version: "0.2.0"}

      html =
        render_component(ApplicationDiagram,
          id: "test",
          vertex: vertex,
          lens: nil,
          theme: :light,
          engine: "dot"
        )

      assert html =~ "Grouped"
      assert html =~ "Coloured"
      assert html =~ "Top"
      assert html =~ "Left"
      assert html =~ "subgraph cluster_dom_Demo_Accounts"
      # Both default toggles (Grouped + Top) are aria-pressed=true
      pressed_count = html |> String.split(~s|aria-pressed="true"|) |> length() |> Kernel.-(1)
      assert pressed_count == 2
    end
  end

  @spec render_dot(:light | :dark) :: String.t()
  defp render_dot(theme) do
    vertex = %Application{app: :clarity, description: nil, version: "0.2.0"}
    {:viz, viz_fn} = ApplicationDiagram.render_static(vertex, nil)
    IO.iodata_to_binary(viz_fn.(%{theme: theme, zoom_subgraph: nil}))
  end
end
