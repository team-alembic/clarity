defmodule Clarity.ReportLiveTest do
  use Clarity.Test.ConnCase, async: true

  describe "ReportLive" do
    test "the reports index opens on the first report", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/reports/ontology"}}} = live(conn, "/reports")
    end

    test "an unknown report id patches to the first report", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/reports/ontology"}}} =
               live(conn, "/reports/nope")
    end

    test "lists every report in the sidebar tree, grouped by category", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports/supply-chain")

      assert has_element?(view, "#report-category-security summary", "Security")
      assert has_element?(view, "#report-category-security a", "Supply chain security")
      assert has_element?(view, "#report-category-security a", "Security posture")
    end

    test "renders the supply-chain report under its name", %{conn: conn} do
      {:ok, view, html} = live(conn, "/reports/supply-chain")

      assert html =~ "Dependency health"
      assert has_element?(view, ".title h1", "Supply chain security")
      assert has_element?(view, "#reports-tree a[aria-current=page]", "Supply chain security")
    end

    test "renders the ontology report under its name, in the Architecture category", %{conn: conn} do
      {:ok, view, html} = live(conn, "/reports/ontology")

      # The test graph has no Ash resources.
      assert html =~ "found any Ash resources"
      assert has_element?(view, ".title h1", "Ontology")
      assert has_element?(view, "#report-category-architecture a[aria-current=page]", "Ontology")
    end

    test "renders the security posture report once its analysis finishes", %{conn: conn} do
      {:ok, view, html} = live(conn, "/reports/security-posture")

      assert html =~ "Analysing"
      # The test graph has no Ash resources.
      assert render_async(view) =~ "found any Ash resources"
    end

    test "choosing another report in the tree patches to it", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports/supply-chain")

      view |> element("#reports-tree a", "Security posture") |> render_click()

      assert_patch(view, "/reports/security-posture")
    end

    test "the activity bar's Reports item toggles the sidebar, and each lens explores",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports/supply-chain")

      assert has_element?(
               view,
               "button#activity-reports[aria-current=page][phx-click*='clarity:toggle-nav']"
             )

      for lens <- ["architect", "security", "documentation", "graph", "debug"] do
        assert has_element?(
                 view,
                 "a#activity-lens-#{lens}[href='/#{lens}'][data-phx-link=redirect]"
               )
      end
    end

    test "the header's menu button shows the sidebar on narrow screens", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports/supply-chain")

      assert has_element?(view, ".navigation.hidden")

      view |> element("button[phx-click='toggle_navigation']") |> render_click()

      assert has_element?(view, ".navigation.block")
    end
  end
end
