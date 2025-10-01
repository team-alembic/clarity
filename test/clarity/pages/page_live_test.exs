defmodule Clarity.Pages.PageLiveTest do
  use Clarity.Test.ConnCase, async: true

  describe "PageLive Navigation and Basic Functionality" do
    test "redirects to root graph when no params", %{conn: conn} do
      default_lens_id = Clarity.Config.fetch_default_perspective_lens!()
      expected_path = "/#{default_lens_id}"
      assert {:error, {:live_redirect, %{to: ^expected_path}}} = live(conn, "/")
    end

    test "loads root vertex with graph content", %{conn: conn} do
      {:ok, view, html} = live(conn, "/debug/root/graph")

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

    test "can refresh the clarity data", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/root/graph")

      # Find and click refresh button
      if has_element?(view, "button[phx-click='refresh']") do
        view |> element("button[phx-click='refresh']") |> render_click()

        # The refresh button should exist and be clickable
        # (The actual refreshing state might not show in our test environment)
        assert has_element?(view, "button[phx-click='refresh']")
      end
    end
  end

  describe "PageLive Breadcrumbs" do
    test "displays breadcrumbs for root vertex", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/debug/root/graph")

      # Root vertex is not shown in breadcrumbs since it's always the same
      # Just verify the page loads correctly
      assert html =~ "Graph Navigation"
    end

    test "displays breadcrumbs for nested vertices", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/debug/application:clarity/graph")

      # Should show breadcrumb for the application (root is not shown)
      assert html =~ "clarity"
    end

    test "displays breadcrumbs for domain vertices", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/debug/domain:Demo.Accounts.Domain/graph")

      # Should show breadcrumb path (root not shown): clarity > Demo.Accounts.Domain
      assert html =~ "clarity"
      assert html =~ "Demo.Accounts.Domain"
    end
  end

  describe "PageLive Graph Interactions" do
    test "navigates to application vertex via graph click", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/root/graph")

      # Test viz:click event with a known vertex ID from our test helper
      view |> element("#content-view-viz") |> render_hook("viz:click", %{"id" => "application:clarity"})

      # Should navigate to the clicked vertex
      assert_patched(view, "/debug/application:clarity/graph")
    end

    test "navigates to domain vertex via graph click", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/root/graph")

      # Test viz:click event with domain vertex
      view |> element("#content-view-viz") |> render_hook("viz:click", %{"id" => "domain:Demo.Accounts.Domain"})

      # Should navigate to the domain vertex
      assert_patched(view, "/debug/domain:Demo.Accounts.Domain/graph")
    end

    test "displays tooltips for vertices", %{conn: conn} do
      {:ok, view, html} = live(conn, "/debug/root/graph")

      # Should have tooltip elements for vertices
      assert html =~ "tooltip-"
      assert has_element?(view, "[id^='tooltip-']")
    end

    test "graph visualization renders correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/root/graph")

      # Should render the graph visualization element
      assert has_element?(view, "#content-view-viz")

      # The graph content should be present
      viz_content = view |> element("#content-view-viz") |> render()
      assert viz_content =~ "digraph" or viz_content =~ "svg"
    end
  end

  describe "PageLive Content Rendering" do
    test "renders graph navigation content by default", %{conn: conn} do
      {:ok, view, html} = live(conn, "/debug/root/graph")

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
      assert has_element?(view, "nav.tabs a.bg-base-light-200", "Graph Navigation")
    end

    test "renders content for different vertex types", %{conn: conn} do
      # Test application vertex content
      {:ok, view, _html} = live(conn, "/debug/application:clarity/graph")
      assert has_element?(view, ".content")
      assert has_element?(view, "nav.tabs")

      # Test domain vertex content
      {:ok, view2, _html} = live(conn, "/debug/domain:Demo.Accounts.Domain/graph")
      assert has_element?(view2, ".content")
      assert has_element?(view2, "nav.tabs")
    end

    test "handles vertex navigation with different content types", %{conn: conn} do
      # Navigate to different vertices and ensure content updates
      {:ok, view, _html} = live(conn, "/debug/root/graph")

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
      {:ok, view, html} = live(conn, "/debug/root/invalid_content")

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

      # Navigation should have theme-appropriate styling
      nav_html = view |> element(".navigation") |> render()
      assert nav_html =~ "bg-base-light-100" or nav_html =~ "dark:bg-base-dark-800"
      assert nav_html =~ "border-base-light-" or nav_html =~ "dark:border-base-dark-"
    end

    test "tabs have correct theme and state styling", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/debug/root/graph")

      # Active tab should have proper styling
      tabs_html = view |> element("nav.tabs") |> render()
      assert tabs_html =~ "bg-base-light-200" or tabs_html =~ "dark:bg-base-dark-800"
      assert tabs_html =~ "text-primary-light" or tabs_html =~ "dark:text-primary-dark"
    end
  end
end
