defmodule Clarity.Pages.PageLiveTest do
  use Clarity.Test.ConnCase, async: true

  alias Phoenix.LiveViewTest.View

  describe "PageLive Navigation and Basic Functionality" do
    test "redirects to root graph when no params", %{conn: conn} do
      default_lens_id = Clarity.Config.fetch_default_perspective_lens!()
      expected_path = "/#{default_lens_id}"
      assert {:error, {:live_redirect, %{to: ^expected_path}}} = live(conn, "/")
    end

    test "a live navigation to a bare lens URL redirects to the lens's start page", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, "/debug/root/graph")

      assert {:error, {:live_redirect, %{to: "/architect/application:clarity"}}} =
               live_redirect(view, to: "/architect")
    end

    test "the activity bar's current Explore item toggles the sidebar", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/root/graph")

      assert has_element?(
               view,
               "button#activity-explore[aria-current=page][phx-click*='clarity:toggle-nav']"
             )
    end

    test "the activity bar's Reports item goes to the lens's reports", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/root/graph")

      assert has_element?(view, "a#activity-reports[href='/debug/reports'][data-phx-link=redirect]")
    end

    test "switching lens keeps the page on screen while the lens's start page loads", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, "/debug/root/graph")
      render_async(view)

      view |> element("button[aria-label='Switch lens perspective']") |> render_click()
      html = view |> element("button[phx-value-lens-id='architect']") |> render_click()

      assert html =~ ~s(class="navigation)
    end

    test "shows no splash while loading once introspection is done", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/debug/root/graph")

      refute html =~ ~s(id="splash")
    end

    test "loads root vertex with graph content", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/root/graph")
      html = render_async(view)

      # Should show the page with navigation
      assert html =~ "Graph Navigation"
      assert has_element?(view, "nav.tabs")
      assert has_element?(view, ".content")

      # Should render the graph visualization
      assert has_element?(view, "#content-view-viz")
    end

    test "can toggle navigation visibility", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/root/graph")

      # Initially navigation should be hidden
      assert has_element?(view, ".navigation.hidden")

      # Toggle navigation
      view |> element("button[phx-click='toggle_navigation']") |> render_click()

      # Navigation should now be visible
      refute has_element?(view, ".navigation.hidden")
      assert has_element?(view, ".navigation.block")
    end

    test "shows navigation tree with correct structure", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/root/graph")

      # Should have navigation section
      assert has_element?(view, ".navigation")

      # Should show tree structure based on our test helper setup
      # Root is not shown in navigation, but should show application
      assert render(view) =~ "clarity"
    end
  end

  describe "PageLive Breadcrumbs" do
    test "displays breadcrumbs for root vertex", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/root/graph")
      html = render_async(view)

      # Root vertex is not shown in breadcrumbs since it's always the same
      # Just verify the page loads correctly
      assert html =~ "Graph Navigation"
    end

    test "displays breadcrumbs for nested vertices", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/application:clarity/graph")
      html = render_async(view)

      # Should show breadcrumb for the application (root is not shown)
      assert html =~ "clarity"
    end

    test "displays breadcrumbs for domain vertices", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/ash-domain:demo-accounts/graph")
      html = render_async(view)

      # Should show breadcrumb path (root not shown): clarity > Demo.Accounts
      assert html =~ "clarity"
      assert html =~ "Demo.Accounts"
    end
  end

  describe "PageLive Graph Interactions" do
    test "navigates to application vertex via graph click", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/root/graph")
      render_async(view)

      # Test viz:click event with a known vertex ID from our test helper
      view |> element("#content-view-viz") |> render_hook("viz:click", %{"id" => "application:clarity"})

      # Should navigate to the clicked vertex
      assert_patched(view, "/debug/application:clarity/graph")
    end

    test "navigates to domain vertex via graph click", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/root/graph")
      render_async(view)

      # Test viz:click event with domain vertex
      view |> element("#content-view-viz") |> render_hook("viz:click", %{"id" => "ash-domain:demo-accounts"})

      # Should navigate to the domain vertex
      assert_patched(view, "/debug/ash-domain:demo-accounts/graph")
    end

    test "graph visualization renders correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/root/graph")
      render_async(view)

      # Should render the graph visualization element
      assert has_element?(view, "#content-view-viz")

      # The graph content should be present
      viz_content = view |> element("#content-view-viz") |> render()
      assert viz_content =~ "digraph" or viz_content =~ "svg"
    end
  end

  describe "PageLive Tooltips" do
    test "renders a single shared tooltip element for the hook", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/root/graph")
      render_async(view)

      assert has_element?(view, "#clarity-tooltip[role='tooltip'][phx-hook='Tooltip']")
    end

    test "renders the icon sprite the hints' type pills refer to", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/application:clarity/graph")
      render_async(view)

      assert has_element?(view, "symbol#clarity-icon-application")

      assert has_element?(
               view,
               ".navigation a[data-tooltip-title='clarity'][data-tooltip-icon='application'][data-tooltip-tone='structure']"
             )
    end

    test "tree links carry the vertex hint inline", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/application:clarity/graph")
      render_async(view)

      assert has_element?(
               view,
               ".navigation a[data-tooltip-title='clarity'][data-tooltip-type='Application'][data-tooltip-text='Clarity App']"
             )
    end

    test "breadcrumb links carry the vertex hint inline", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/ash-domain:demo-accounts/graph")
      render_async(view)

      assert has_element?(
               view,
               ".breadcrumbs a[data-tooltip-title='clarity'][data-tooltip-type='Application']"
             )
    end

    test "graph visualisations ship each vertex's full hint", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/root/graph")
      render_async(view)

      hints =
        view
        |> element("#content-view-viz")
        |> render()
        |> LazyHTML.from_fragment()
        |> LazyHTML.attribute("data-tooltips")
        |> List.first()
        |> JSON.decode!()

      assert hints["application:clarity"] == %{
               "title" => "clarity",
               "type" => "Application",
               "icon" => "application",
               "tone" => "structure",
               "text" => "Clarity App",
               "facts" => [["Version", "0.1.0"]]
             }
    end
  end

  describe "PageLive lens tabs" do
    test "the Graph lens shows only the graph tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/graph/root/graph")
      render_async(view)

      tabs = view |> render() |> LazyHTML.from_fragment() |> LazyHTML.query(".content-tab")

      assert Enum.map(tabs, &(&1 |> LazyHTML.text() |> String.trim())) == ["Graph Navigation"]
    end

    test "the Documentation lens shows a domain's overview, not its graph", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/documentation/ash-domain:demo-accounts/ash-domain-overview")
      render_async(view)

      assert has_element?(view, ".content-tab", "Domain Overview")
      refute has_element?(view, ".content-tab", "Graph Navigation")
    end
  end

  describe "PageLive Content Rendering" do
    test "renders graph navigation content by default", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/root/graph")
      html = render_async(view)

      # Should render viz content by default (Graph Navigation)
      assert has_element?(view, "#content-view-viz")
      assert html =~ "Graph Navigation"
    end

    test "switches between different content tabs", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/root/graph")

      # Should have at least the Graph Navigation tab
      assert has_element?(view, "nav.tabs")
      assert has_element?(view, "nav.tabs a", "Graph Navigation")

      # Graph Navigation should be the active tab
      assert has_element?(view, "nav.tabs a[aria-current='page']", "Graph Navigation")
    end

    test "renders content for different vertex types", %{conn: conn} do
      # Test application vertex content
      {:ok, view, _html} = live(conn, "/debug/application:clarity/graph")
      assert has_element?(view, ".content")
      assert has_element?(view, "nav.tabs")

      # Test domain vertex content
      {:ok, view2, _html} = live(conn, "/debug/ash-domain:demo-accounts/graph")
      assert has_element?(view2, ".content")
      assert has_element?(view2, "nav.tabs")
    end

    test "handles vertex navigation with different content types", %{conn: conn} do
      # Navigate to different vertices and ensure content updates
      {:ok, view, _html} = live(conn, "/debug/root/graph")
      render_async(view)

      # Navigate to application vertex
      view |> element("#content-view-viz") |> render_hook("viz:click", %{"id" => "application:clarity"})
      assert_patched(view, "/debug/application:clarity/graph")

      # Content should update for the new vertex
      assert has_element?(view, ".content")
    end
  end

  describe "PageLive Error Handling" do
    test "shows 404 page for invalid lens", %{conn: conn} do
      # Test with invalid lens ID should show lens 404 error
      {:ok, view, html} = live(conn, "/invalid_lens/root/graph")

      # Should show lens not found error
      assert html =~ "Lens Not Found"
      assert html =~ "Go to Default Page"

      # Should not show normal page layout
      refute has_element?(view, "nav.tabs")
      refute has_element?(view, ".navigation")

      # Should have link to default page
      assert has_element?(view, "a[href='/']")
    end

    test "shows 404 page for invalid vertex", %{conn: conn} do
      # Test with invalid vertex ID should show vertex 404 error
      {:ok, view, html} = live(conn, "/debug/invalid_vertex/graph")

      # Should show vertex not found error
      assert html =~ "Vertex Not Found"
      assert html =~ "Go to Root"

      # Should not show tabs
      refute has_element?(view, "nav.tabs")

      # Should have link to root
      assert has_element?(view, "a[href='/debug/root']")
    end

    test "shows content 404 for invalid content", %{conn: conn} do
      # Test with valid vertex but invalid content should show content 404
      {:ok, view, _html} = live(conn, "/debug/root/invalid_content")
      html = render_async(view)

      # Should show content not found error inside the content area
      assert html =~ "Content Not Found"
      assert html =~ "Try selecting a different tab"

      # Should still show tabs for the valid vertex
      assert has_element?(view, "nav.tabs")
      assert html =~ "Graph Navigation"
    end
  end

  describe "PageLive Theme and UI State" do
    test "maintains theme state across navigation", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/root/graph")

      # Should have theme-related classes
      page_html = render(view)
      assert page_html =~ "bg-base-light-50" or page_html =~ "dark:bg-base-dark-900"
    end

    test "applies correct CSS classes for light and dark themes", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/root/graph")

      # Should have both light and dark mode classes for proper theming
      page_html = render(view)
      assert page_html =~ "text-base-light-900" or page_html =~ "dark:text-base-dark-100"
      assert page_html =~ "bg-base-light-" or page_html =~ "dark:bg-base-dark-"
    end

    test "navigation panel has correct theme classes", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/root/graph")
      # The panel renders once the graph has loaded.
      render_async(view)

      # Navigation should have theme-appropriate styling
      nav_html = view |> element(".navigation") |> render()
      assert nav_html =~ "bg-base-light-100" or nav_html =~ "dark:bg-base-dark-800"
      assert nav_html =~ "border-base-light-" or nav_html =~ "dark:border-base-dark-"
    end

    test "marks the tab being shown as the current one", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/application:clarity/graph")
      render_async(view)

      assert has_element?(view, "nav.tabs a[aria-current='page']", "Graph Navigation")

      current =
        view |> element("nav.tabs") |> render() |> LazyHTML.from_fragment() |> LazyHTML.query("a[aria-current]")

      assert Enum.count(current) == 1
    end
  end

  describe "PageLive framework internals" do
    @describetag test_graph: [internals: true]

    test "are shown in the Debug lens, with no toggle", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/application:clarity/graph")
      render_async(view)

      assert has_element?(view, ".navigation a[data-tooltip-title='ash']")
      refute has_element?(view, "#toggle-internals")
    end

    for lens <- ["architect", "security"] do
      test "are never shown in the #{lens} lens, nor an application that only holds them", %{conn: conn} do
        {:ok, view, _html} = live_lens(conn, unquote(lens))

        refute has_element?(view, ".navigation a[data-tooltip-title='ash']")
        refute has_element?(view, ".navigation a[data-tooltip-title='Ash.EmbeddableType.ShadowDomain']")
        refute has_element?(view, "#toggle-internals")
      end
    end

    test "stay reachable: navigating to one shows it, even where they are hidden", %{conn: conn} do
      {:ok, view, _html} =
        live(conn, "/architect/ash-domain:ash-embeddable-type-shadow-domain/graph")

      render_async(view)

      assert has_element?(
               view,
               ".navigation a[data-tooltip-title='Ash.EmbeddableType.ShadowDomain']"
             )
    end

    # Opens the lens at the clarity application, following the lens's
    # redirect to its own starting tab.
    @spec live_lens(Plug.Conn.t(), String.t()) :: {:ok, %View{}, String.t()}
    defp live_lens(conn, lens) do
      {:ok, view, html} =
        case live(conn, "/#{lens}/application:clarity") do
          {:error, {:live_redirect, %{to: path}}} -> live(conn, path)
          result -> result
        end

      render_async(view)
      {:ok, view, html}
    end
  end

  describe "PageLive navigation tree" do
    @clarity_node "details[id='tree-node-application:clarity']"

    test "navigating to a vertex opens the tree down to it", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/root/graph")
      render_async(view)

      refute has_element?(view, "#{@clarity_node}[open]")

      render_patch(view, "/debug/ash-domain:demo-accounts/graph")
      render_async(view)

      assert has_element?(view, "#{@clarity_node}[open]")
    end

    test "a node on the path to the current vertex can be collapsed", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/ash-domain:demo-accounts/graph")
      render_async(view)

      toggle_clarity(view, false)

      refute has_element?(view, "#{@clarity_node}[open]")
    end

    test "a collapsed node stays collapsed until the user navigates elsewhere", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/ash-domain:demo-accounts/graph")
      render_async(view)
      toggle_clarity(view, false)

      render_patch(view, "/debug/ash-domain:demo-accounts/graph")
      render_async(view)

      refute has_element?(view, "#{@clarity_node}[open]")

      render_patch(view, "/debug/root/graph")
      render_async(view)
      render_patch(view, "/debug/ash-domain:demo-accounts/graph")
      render_async(view)

      assert has_element?(view, "#{@clarity_node}[open]")
    end

    test "a node opened by navigation stays open when navigating elsewhere", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/ash-domain:demo-accounts/graph")
      render_async(view)

      render_patch(view, "/debug/root/graph")
      render_async(view)

      assert has_element?(view, "#{@clarity_node}[open]")
    end

    test "a node the user expanded stays open when navigating elsewhere", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/root/graph")
      render_async(view)
      toggle_clarity(view, true)

      render_patch(view, "/debug/ash-domain:demo-accounts/graph")
      render_async(view)
      render_patch(view, "/debug/root/graph")
      render_async(view)

      assert has_element?(view, "#{@clarity_node}[open]")
    end

    test "toggling sets the state the user asked for", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/root/graph")
      render_async(view)

      toggle_clarity(view, true)
      toggle_clarity(view, true)

      assert has_element?(view, "#{@clarity_node}[open]")

      toggle_clarity(view, false)
      toggle_clarity(view, false)

      refute has_element?(view, "#{@clarity_node}[open]")
    end

    test "marks the current vertex's label so it can toggle in place", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/application:clarity/graph")
      render_async(view)

      assert has_element?(view, ".navigation a[aria-current='page'][data-tooltip-title='clarity']")
      assert has_element?(view, ".navigation a[data-tooltip-title='Demo.Accounts']")
      refute has_element?(view, ".navigation a[aria-current][data-tooltip-title='Demo.Accounts']")
    end

    test "shows short module names, with the full name in the hint", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/ash-domain:demo-accounts/graph")
      render_async(view)

      label =
        view
        |> element(".navigation a[data-tooltip-title='Demo.Accounts']")
        |> render()
        |> LazyHTML.from_fragment()
        |> LazyHTML.text()
        |> String.trim()

      assert label == "Accounts"
    end

    test "has a resizable, collapsible panel", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/application:clarity/graph")
      render_async(view)

      assert has_element?(view, "#nav-resize[role='separator'][phx-hook='NavPanel']")
    end

    test "is shown and hidden from the activity bar, not buttons of its own", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/application:clarity/graph")
      render_async(view)

      assert has_element?(view, "#activity-bar button#activity-explore")
      refute has_element?(view, "#hide-nav")
      refute has_element?(view, "#show-nav")
      refute has_element?(view, "header #toggle-sidebar")
    end

    @clarity_group "details[id='tree-group-application:clarity/child']"

    test "a vertex row shows its type's icon in its colour", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/application:clarity/graph")
      render_async(view)

      assert has_element?(
               view,
               ".navigation a[data-tooltip-title='Demo.Accounts'] .tree-icon[data-tone='structure'] use[href='#clarity-icon-domain']"
             )
    end

    @tag test_graph: [modules: true]
    test "a group row is a plain label, like a folder", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/application:clarity/graph")
      render_async(view)

      assert has_element?(view, "#{@clarity_group} > summary", "child")
      refute has_element?(view, "#{@clarity_group} > summary svg use")
    end

    @tag test_graph: [modules: true]
    test "a group can be collapsed and expanded", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/application:clarity/graph")
      render_async(view)

      assert has_element?(view, "#{@clarity_group}[open]")

      toggle_clarity_group(view, false)

      refute has_element?(view, "#{@clarity_group}[open]")

      toggle_clarity_group(view, true)

      assert has_element?(view, "#{@clarity_group}[open]")
    end

    @tag test_graph: [modules: true]
    test "navigating into a collapsed group reveals it", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/application:clarity/graph")
      render_async(view)
      toggle_clarity_group(view, false)

      render_patch(view, "/debug/ash-domain:demo-accounts/graph")
      render_async(view)

      assert has_element?(view, "#{@clarity_group}[open]")
    end

    @tag test_graph: [modules: true]
    test "a collapsed group stays collapsed when navigating past it", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/root/graph")
      render_async(view)
      toggle_clarity(view, true)
      toggle_clarity_group(view, false)

      render_patch(view, "/debug/application:clarity/graph")
      render_async(view)

      assert has_element?(view, "#{@clarity_node}[open]")
      refute has_element?(view, "#{@clarity_group}[open]")
    end

    @spec toggle_clarity_group(%View{}, boolean()) :: String.t()
    defp toggle_clarity_group(view, open) do
      view
      |> element(@clarity_group)
      |> render_hook("toggle_group", %{"group_id" => "application:clarity/child", "open" => open})
    end

    @spec toggle_clarity(%View{}, boolean()) :: String.t()
    defp toggle_clarity(view, open) do
      view
      |> element(@clarity_node)
      |> render_hook("toggle", %{"vertex_id" => "application:clarity", "open" => open})
    end
  end
end
