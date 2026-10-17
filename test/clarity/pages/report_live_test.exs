defmodule Clarity.ReportLiveTest do
  use Clarity.Test.ConnCase, async: true

  describe "ReportLive" do
    test "the reports index opens on the first report", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/clarity/reports/ontology"}}} = live(conn, "/clarity/reports")
    end

    test "an unknown report id patches to the first report", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/clarity/reports/ontology"}}} =
               live(conn, "/clarity/reports/nope")
    end

    test "lists every report in the sidebar tree, grouped by category", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/clarity/reports/supply-chain")

      assert has_element?(view, "#report-category-security summary", "Security")
      assert has_element?(view, "#report-category-security a", "Supply chain security")
      assert has_element?(view, "#report-category-security a", "Security posture")
    end

    test "renders the supply-chain report under its name", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/clarity/reports/supply-chain")
      render_async(view)

      assert has_element?(view, ".report-status")
      assert has_element?(view, ".title h1", "Supply chain security")
      assert has_element?(view, "#reports-tree a[aria-current=page]", "Supply chain security")
    end

    test "renders the ontology report under its name, in the Architecture category", %{conn: conn} do
      {:ok, view, html} = live(conn, "/clarity/reports/ontology")

      # The test graph has no Ash resources.
      assert html =~ "No Ash resources found"
      assert has_element?(view, ".title h1", "Ontology")
      assert has_element?(view, "#report-category-architecture a[aria-current=page]", "Ontology")
    end

    test "renders the security posture report once its analysis finishes", %{conn: conn} do
      {:ok, view, html} = live(conn, "/clarity/reports/security-posture")

      assert html =~ "Analysing"
      # The test graph has no Ash resources.
      assert render_async(view) =~ "No Ash resources found"
    end

    test "choosing another report in the tree patches to it", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/clarity/reports/supply-chain")

      view |> element("#reports-tree a", "Security posture") |> render_click()

      assert_patch(view, "/clarity/reports/security-posture")
    end

    test "the activity bar's Reports item toggles the sidebar, and each lens explores",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, "/clarity/reports/supply-chain")

      assert has_element?(
               view,
               "button#activity-reports[aria-current=page][phx-click*='clarity:toggle-nav']"
             )

      for lens <- ["architect", "security", "documentation", "graph", "debug"] do
        assert has_element?(
                 view,
                 "a#activity-lens-#{lens}[href='/clarity/#{lens}'][data-phx-link=redirect]"
               )
      end
    end

    test "the activity bar has Actions above Reports", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/clarity/reports/supply-chain")

      assert has_element?(view, "a#activity-actions[href='/clarity/actions']")

      assert view
             |> render()
             |> LazyHTML.from_fragment()
             |> LazyHTML.query(".activity-item")
             |> Enum.map(&LazyHTML.attribute(&1, "id"))
             |> List.flatten()
             |> Enum.take(-2) ==
               ["activity-actions", "activity-reports"]
    end

    test "a report counts its things to do, linking to them under Actions", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/clarity/reports/security-posture")
      render_async(view)

      # The test graph has no Ash resources, so there's nothing to do.
      assert has_element?(view, ".report-status[data-tone='ok']", "Nothing to do")
    end
  end

  describe "ReportLive under Actions" do
    test "the index opens on the first report with things to do", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/clarity/actions/ontology"}}} = live(conn, "/clarity/actions")
    end

    test "lists only the reports with things to do, in the same tree", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/clarity/actions/supply-chain")

      assert has_element?(view, ".nav-heading", "Actions")
      assert has_element?(view, "#report-category-security a[href='/clarity/actions/security-posture']")
      assert has_element?(view, "#reports-tree a[aria-current=page]", "Supply chain security")
      assert has_element?(view, "button#activity-actions[aria-current=page]")
    end

    test "shows a report's things to do, and links to the report", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/clarity/actions/security-posture")
      render_async(view)

      assert has_element?(view, "#report-actions .report-status", "Nothing to do")
      assert has_element?(view, "a#read-report[href='/clarity/reports/security-posture']")
    end
  end

  describe "ReportLive sidebar" do
    test "the header's menu button shows the sidebar on narrow screens", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/clarity/reports/supply-chain")

      assert has_element?(view, ".navigation.hidden")

      view |> element("button[phx-click='toggle_navigation']") |> render_click()

      assert has_element?(view, ".navigation.block")
    end
  end
end
