defmodule Clarity.CoreComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest

  alias Clarity.Content
  alias Clarity.CoreComponents
  alias Clarity.Graph
  alias Clarity.Perspective.Lens
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Domain
  alias Clarity.Vertex.Ash.Resource
  alias Clarity.Vertex.Root
  alias Demo.Accounts.User

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

  describe "empty_state/1" do
    test "shows an icon, a title, what to do and a way on" do
      assigns = %{}

      doc =
        ~H"""
        <CoreComponents.empty_state title="Nothing here" id="empty">
          <:icon><svg id="icon" /></:icon>
          Pick something else.
          <:action><a href="/elsewhere">Elsewhere</a></:action>
        </CoreComponents.empty_state>
        """
        |> rendered_to_string()
        |> LazyHTML.from_fragment()

      assert doc |> LazyHTML.query("#empty.empty-state .empty-state-icon #icon") |> Enum.count() == 1
      assert doc |> LazyHTML.query("#empty .empty-state-title") |> LazyHTML.text() == "Nothing here"
      assert doc |> LazyHTML.query("#empty .empty-state-text") |> LazyHTML.text() =~ "Pick something else."
      assert doc |> LazyHTML.query("#empty .empty-state-actions a[href='/elsewhere']") |> Enum.count() == 1
    end

    test "leaves out the actions when there are none" do
      assigns = %{}

      doc =
        ~H"""
        <CoreComponents.empty_state title="Nothing here">
          <:icon><svg /></:icon>
        </CoreComponents.empty_state>
        """
        |> rendered_to_string()
        |> LazyHTML.from_fragment()

      assert doc |> LazyHTML.query(".empty-state-actions") |> Enum.empty?()
    end
  end

  describe "data_load_error/1" do
    test "says the page couldn't load and links home, to the lens's start page" do
      lens = %Lens{id: "graph", name: "Graph", icon: fn -> nil end, filter: true}
      doc = (&CoreComponents.data_load_error/1) |> render_component(prefix: "/", lens: lens) |> LazyHTML.from_fragment()

      assert doc |> LazyHTML.query("#data-load-error.empty-state .empty-state-title") |> LazyHTML.text() ==
               "Couldn't load this page"

      assert doc |> LazyHTML.query(".empty-state-actions a[href='/graph']") |> Enum.count() == 1
    end
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
          clarity_pid: self(),
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

    test "the view source button is an icon button with a name and a hover hint" do
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
             |> LazyHTML.query(
               "button.icon-button[phx-click='toggle_raw_drawer'][aria-label='View source'][data-tooltip-text='View source']"
             )
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

  describe "raw_content_drawer/1" do
    @spec drawer(boolean(), String.t()) :: LazyHTML.t()
    defp drawer(show, content_type) do
      (&CoreComponents.raw_content_drawer/1)
      |> render_component(show: show, content_type: content_type, raw_content: "flowchart LR")
      |> LazyHTML.from_fragment()
    end

    test "is a dialog titled by the source's format" do
      doc = drawer(true, "mermaid")

      assert doc |> LazyHTML.query("#raw-content-drawer[role='dialog']") |> Enum.count() == 1
      assert doc |> LazyHTML.query("#raw-content-drawer-title") |> LazyHTML.text() =~ "Mermaid source"

      assert true |> drawer("graphviz") |> LazyHTML.query("#raw-content-drawer-title") |> LazyHTML.text() =~
               "Graphviz source"
    end

    test "closes on Escape only while open" do
      assert true
             |> drawer("mermaid")
             |> LazyHTML.query("#raw-content-drawer[phx-window-keydown='close_raw_drawer'][phx-key='Escape']")
             |> Enum.count() == 1

      assert false |> drawer("mermaid") |> LazyHTML.query("[phx-window-keydown]") |> Enum.empty?()
    end
  end

  describe "vertex_name/1" do
    test "shows the qualified name by default" do
      html =
        render_component(&CoreComponents.vertex_name/1,
          vertex: %Resource{resource: User}
        )

      assert html |> LazyHTML.from_fragment() |> LazyHTML.text() == "Demo.Accounts.User"
    end

    test "shows a given name in place of its own" do
      html =
        render_component(&CoreComponents.vertex_name/1,
          vertex: %Resource{resource: User},
          name: "Accounts.User"
        )

      assert html |> LazyHTML.from_fragment() |> LazyHTML.text() == "Accounts.User"
    end

    test "shows just the last segment of a module name in the short style" do
      html =
        render_component(&CoreComponents.vertex_name/1,
          vertex: %Domain{domain: Demo.Accounts},
          name_style: :short
        )

      assert html |> LazyHTML.from_fragment() |> LazyHTML.text() == "Accounts"
    end
  end
end
