defmodule Clarity.ReportLiveTest do
  use Clarity.Test.ConnCase, async: true

  describe "ReportLive" do
    test "the reports index opens on the first report", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/security/reports/security-posture"}}} =
               live(conn, "/security/reports")
    end

    test "an unknown report id patches to the first report", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/architect/reports/security-posture"}}} =
               live(conn, "/architect/reports/nope")
    end

    test "an unknown lens moves to the default lens's reports", %{conn: conn} do
      default = Clarity.Config.fetch_default_perspective_lens!()
      expected = "/#{default}/reports"

      assert {:error, {:live_redirect, %{to: ^expected}}} = live(conn, "/nolens/reports")
    end

    test "lists every report in the sidebar tree under any lens", %{conn: conn} do
      for lens <- ["architect", "security", "debug"] do
        {:ok, view, _html} = live(conn, "/#{lens}/reports/supply-chain")

        assert has_element?(view, "#reports-tree a", "Supply chain security")
        assert has_element?(view, "#reports-tree a", "Security posture")
      end
    end

    test "groups the reports by category", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/security/reports/supply-chain")

      assert has_element?(view, "#report-category-security summary", "Security")
      assert has_element?(view, "#report-category-security a", "Supply chain security")
      assert has_element?(view, "#report-category-security a", "Security posture")
    end

    test "renders the supply-chain report under its name", %{conn: conn} do
      {:ok, view, html} = live(conn, "/security/reports/supply-chain")

      assert html =~ "Dependency health"
      assert has_element?(view, ".title h1", "Supply chain security")
      assert has_element?(view, "#reports-tree a[aria-current=page]", "Supply chain security")
    end

    test "renders the security posture report once its analysis finishes", %{conn: conn} do
      {:ok, view, html} = live(conn, "/security/reports/security-posture")

      assert html =~ "Analysing"
      # The test graph has no Ash resources.
      assert render_async(view) =~ "found any Ash resources"
    end

    test "choosing another report in the tree patches to it", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/security/reports/supply-chain")

      view |> element("#reports-tree a", "Security posture") |> render_click()

      assert_patch(view, "/security/reports/security-posture")
    end

    test "the activity bar's current Reports item toggles the sidebar, and Explore goes back",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, "/security/reports/supply-chain")

      assert has_element?(
               view,
               "button#activity-reports[aria-current=page][phx-click*='clarity:toggle-nav']"
             )

      assert has_element?(view, "a#activity-explore[href='/security'][data-phx-link=redirect]")
    end

    test "the header's menu button shows the sidebar on narrow screens", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/security/reports/supply-chain")

      assert has_element?(view, ".navigation.hidden")

      view |> element("button[phx-click='toggle_navigation']") |> render_click()

      assert has_element?(view, ".navigation.block")
    end

    test "switching lens keeps the report shown", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/security/reports/supply-chain")

      view |> element("button[aria-label='Switch lens perspective']") |> render_click()
      view |> element("button[phx-value-lens-id='architect']") |> render_click()

      assert_patch(view, "/architect/reports/supply-chain")
    end
  end
end
