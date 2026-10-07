defmodule Clarity.CoreComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Clarity.Content
  alias Clarity.CoreComponents
  alias Clarity.Graph
  alias Clarity.Perspective.Lens
  alias Clarity.Vertex
  alias Clarity.Vertex.Root

  @spec content(String.t(), String.t(), [atom()]) :: Content.t()
  defp content(id, name, status_classes) do
    %Content{
      id: id,
      name: name,
      provider: __MODULE__,
      live_view?: false,
      live_component?: false,
      status_classes: status_classes
    }
  end

  @spec tabs(map()) :: String.t()
  defp tabs(vertex_status_classes) do
    render_component(&CoreComponents.tabs/1,
      contents: [content("overview", "Overview", []), content("version", "Version Status", [:hygiene])],
      content: nil,
      prefix: "/c",
      lens: %Lens{id: "security", name: "Security", icon: fn -> nil end, filter: true},
      vertex: %Root{},
      vertex_status_classes: vertex_status_classes
    )
  end

  describe "tabs/1 status dots" do
    test "flags the tab whose class the vertex carries" do
      html = tabs(%{hygiene: :info})

      assert html =~ "bg-blue-500"
    end

    test "shows no dot when the vertex carries no surfaced status" do
      html = tabs(%{})

      refute html =~ "bg-blue-500"
      refute html =~ "bg-red-500"
      refute html =~ "bg-yellow-500"
    end
  end

  describe "render_content/1 static graphviz content" do
    test "ships hover hints for the vertices in the zoomed graph" do
      graph = Graph.new()
      app = %Vertex.Application{app: :demo, description: "Demo app.", version: "1.0.0"}
      Graph.add_vertex(graph, app, %Root{})

      html =
        render_component(&CoreComponents.render_content/1,
          content: %Content{
            id: "static-graph",
            name: "Static Graph",
            provider: __MODULE__,
            live_view?: false,
            live_component?: false,
            render_static: {:viz, fn _props -> "digraph {}" end}
          },
          vertex: %Root{},
          lens: %Lens{id: "debug", name: "Debug", icon: fn -> nil end, filter: true},
          socket: %Phoenix.LiveView.Socket{},
          theme: :light,
          zoom_graph: graph,
          zoom_level: {1, 1},
          shown_vertex_types: [],
          available_vertex_types: [],
          prefix: "/c"
        )

      hints =
        html
        |> LazyHTML.from_fragment()
        |> LazyHTML.query("#content-view-viz")
        |> LazyHTML.attribute("data-tooltips")
        |> List.first()
        |> JSON.decode!()

      assert hints == %{
               "application:demo" => %{
                 "title" => "demo",
                 "type" => "Application",
                 "icon" => "application",
                 "tone" => "structure",
                 "text" => "Demo app.",
                 "facts" => [["Version", "1.0.0"]]
               }
             }
    end
  end

  describe "tabs/1 hints" do
    test "a tab's description becomes its hover hint" do
      html =
        render_component(&CoreComponents.tabs/1,
          contents: [%{content("overview", "Overview", []) | description: "What this vertex is"}],
          content: nil,
          prefix: "/c",
          lens: %Lens{id: "debug", name: "Debug", icon: fn -> nil end, filter: true},
          vertex: %Root{},
          vertex_status_classes: %{}
        )

      assert html
             |> LazyHTML.from_fragment()
             |> LazyHTML.query("a[data-tooltip-text='What this vertex is']")
             |> Enum.count() == 1
    end

    test "the raw source button has a hover hint" do
      static = %{content("graph", "Graph", []) | render_static: {:markdown, fn _ -> "" end}}

      html =
        render_component(&CoreComponents.tabs/1,
          contents: [static],
          content: static,
          prefix: "/c",
          lens: %Lens{id: "debug", name: "Debug", icon: fn -> nil end, filter: true},
          vertex: %Root{},
          vertex_status_classes: %{}
        )

      assert html
             |> LazyHTML.from_fragment()
             |> LazyHTML.query("button[phx-click='toggle_raw_drawer'][data-tooltip-text='Show raw source']")
             |> Enum.count() == 1
    end
  end

  describe "raw_content_drawer/1 icon buttons" do
    test "keep an accessible name and gain a hover hint" do
      doc =
        (&CoreComponents.raw_content_drawer/1)
        |> render_component(
          show: true,
          content_type: "markdown",
          raw_content: "# hi"
        )
        |> LazyHTML.from_fragment()

      for label <- ["Copy to clipboard", "Close"] do
        assert doc |> LazyHTML.query("button[aria-label='#{label}'][data-tooltip-text='#{label}']") |> Enum.count() == 1
      end
    end
  end

  describe "vertex_name/1" do
    test "lets a dotted name wrap between its segments, not mid-word" do
      html =
        render_component(&CoreComponents.vertex_name/1,
          vertex: %Vertex.Ash.Domain{domain: Demo.Accounts.Domain}
        )

      doc = LazyHTML.from_fragment(html)

      assert LazyHTML.text(doc) == "Demo.Accounts.Domain"
      assert doc |> LazyHTML.query("span > wbr") |> Enum.count() == 2
    end
  end
end
