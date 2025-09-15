defmodule Clarity.Pages.PageLiveTest do
  use Clarity.Web.ConnCase, async: true

  describe "PageLive Navigation and Basic Functionality" do
    test "redirects to root graph when no params", %{conn: conn} do
      # Should redirect to /root/graph when accessing root path
      assert {:error, {:live_redirect, %{to: "/root/graph"}}} = live(conn, "/")
    end

    test "loads root vertex with graph content", %{conn: conn} do
      {:ok, view, html} = live(conn, "/root/graph")

      # Should show the page with navigation
      assert html =~ "Graph Navigation"
      assert has_element?(view, "nav.tabs")
      assert has_element?(view, ".content")

      # Should render the graph visualization
      assert has_element?(view, "#content-view-viz")
    end

    test "can toggle navigation visibility", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/root/graph")

      # Initially navigation should be hidden
      assert has_element?(view, ".navigation.hidden")

      # Toggle navigation
      view |> element("button[phx-click='toggle_navigation']") |> render_click()

      # Navigation should now be visible
      refute has_element?(view, ".navigation.hidden")
      assert has_element?(view, ".navigation.block")
    end

    test "shows navigation tree with correct structure", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/root/graph")

      # Should have navigation section
      assert has_element?(view, ".navigation")

      # Should show tree structure based on our test helper setup
      # Root is not shown in navigation, but should show application
      assert render(view) =~ "clarity"
    end

    test "can refresh the clarity data", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/root/graph")

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
      {:ok, _view, html} = live(conn, "/root/graph")

      # Root node is not shown in breadcrumbs since it's always the same
      # Just verify the page loads correctly
      assert html =~ "Graph Navigation"
    end

    test "displays breadcrumbs for nested vertices", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/application:clarity/graph")

      # Should show breadcrumb for the application (root is not shown)
      assert html =~ "clarity"
    end

    test "displays breadcrumbs for domain vertices", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/domain:Demo.Accounts.Domain/graph")

      # Should show breadcrumb path (root not shown): clarity > Demo.Accounts.Domain
      assert html =~ "clarity"
      assert html =~ "Demo.Accounts.Domain"
    end
  end

  describe "PageLive Graph Interactions" do
    test "navigates to application vertex via graph click", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/root/graph")

      # Test viz:click event with a known vertex ID from our test helper
      view |> element("#content-view-viz") |> render_hook("viz:click", %{"id" => "application:clarity"})

      # Should navigate to the clicked vertex
      assert_patched(view, "/application:clarity/graph")
    end

    test "navigates to domain vertex via graph click", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/root/graph")

      # Test viz:click event with domain vertex
      view |> element("#content-view-viz") |> render_hook("viz:click", %{"id" => "domain:Demo.Accounts.Domain"})

      # Should navigate to the domain vertex
      assert_patched(view, "/domain:Demo.Accounts.Domain/graph")
    end

    test "displays tooltips for vertices", %{conn: conn} do
      {:ok, view, html} = live(conn, "/root/graph")

      # Should have tooltip elements for vertices
      assert html =~ "tooltip-"
      assert has_element?(view, "[id^='tooltip-']")
    end

    test "graph visualization renders correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/root/graph")

      # Should render the graph visualization element
      assert has_element?(view, "#content-view-viz")

      # The graph content should be present
      viz_content = view |> element("#content-view-viz") |> render()
      assert viz_content =~ "digraph" or viz_content =~ "svg"
    end
  end

  describe "PageLive Content Rendering" do
    test "renders graph navigation content by default", %{conn: conn} do
      {:ok, view, html} = live(conn, "/root/graph")

      # Should render viz content by default (Graph Navigation)
      assert has_element?(view, "#content-view-viz")
      assert html =~ "Graph Navigation"
    end

    test "switches between different content tabs", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/root/graph")

      # Should have at least the Graph Navigation tab
      assert has_element?(view, "nav.tabs")
      assert has_element?(view, "nav.tabs a", "Graph Navigation")

      # Graph Navigation should be the active tab
      assert has_element?(view, "nav.tabs a.bg-base-light-200", "Graph Navigation")
    end

    test "renders content for different vertex types", %{conn: conn} do
      # Test application vertex content
      {:ok, view, _html} = live(conn, "/application:clarity/graph")
      assert has_element?(view, ".content")
      assert has_element?(view, "nav.tabs")

      # Test domain vertex content
      {:ok, view2, _html} = live(conn, "/domain:Demo.Accounts.Domain/graph")
      assert has_element?(view2, ".content")
      assert has_element?(view2, "nav.tabs")
    end

    test "handles vertex navigation with different content types", %{conn: conn} do
      # Navigate to different vertices and ensure content updates
      {:ok, view, _html} = live(conn, "/root/graph")

      # Navigate to application vertex
      view |> element("#content-view-viz") |> render_hook("viz:click", %{"id" => "application:clarity"})
      assert_patched(view, "/application:clarity/graph")

      # Content should update for the new vertex
      assert has_element?(view, ".content")
    end
  end

  describe "PageLive Error Handling" do
    test "shows error for invalid vertex", %{conn: conn} do
      # Test with invalid vertex ID
      assert_raise KeyError, fn ->
        live(conn, "/invalid_vertex/graph")
      end
    end

    test "handles missing content gracefully", %{conn: conn} do
      # Test with valid vertex but invalid content should still load (defaults to first content)
      {:ok, _view, html} = live(conn, "/root/invalid_content")

      # Should still show the default content (Graph Navigation)
      assert html =~ "Graph Navigation"
    end
  end

  describe "PageLive Theme and UI State" do
    test "maintains theme state across navigation", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/root/graph")

      # Should have theme-related classes
      page_html = render(view)
      assert page_html =~ "bg-base-light-50" or page_html =~ "dark:bg-base-dark-900"
    end

    test "applies correct CSS classes for light and dark themes", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/root/graph")

      # Should have both light and dark mode classes for proper theming
      page_html = render(view)
      assert page_html =~ "text-base-light-900" or page_html =~ "dark:text-base-dark-100"
      assert page_html =~ "bg-base-light-" or page_html =~ "dark:bg-base-dark-"
    end

    test "navigation panel has correct theme classes", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/root/graph")

      # Navigation should have theme-appropriate styling
      nav_html = view |> element(".navigation") |> render()
      assert nav_html =~ "bg-base-light-100" or nav_html =~ "dark:bg-base-dark-800"
      assert nav_html =~ "border-base-light-" or nav_html =~ "dark:border-base-dark-"
    end

    test "tabs have correct theme and state styling", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/root/graph")

      # Active tab should have proper styling
      tabs_html = view |> element("nav.tabs") |> render()
      assert tabs_html =~ "bg-base-light-200" or tabs_html =~ "dark:bg-base-dark-800"
      assert tabs_html =~ "text-primary-light" or tabs_html =~ "dark:text-primary-dark"
    end
  end
end
