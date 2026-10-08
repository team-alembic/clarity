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

    test "lists every report under any lens", %{conn: conn} do
      for lens <- ["architect", "security", "debug"] do
        {:ok, view, _html} = live(conn, "/#{lens}/reports/supply-chain")

        assert has_element?(view, "#report-tabs a", "Supply chain security")
        assert has_element?(view, "#report-tabs a", "Security posture")
      end
    end

    test "renders the supply-chain report", %{conn: conn} do
      {:ok, view, html} = live(conn, "/security/reports/supply-chain")

      assert html =~ "Dependency health"
      assert has_element?(view, "#report-tabs a[aria-current=page]", "Supply chain security")
    end

    test "renders the security posture report", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/security/reports/security-posture")

      # The test graph has no Ash resources.
      assert html =~ "found any Ash resources"
    end

    test "switching report tabs patches to the other report", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/security/reports/supply-chain")

      view |> element("#report-tabs a", "Security posture") |> render_click()

      assert_patch(view, "/security/reports/security-posture")
    end

    test "marks Reports as the current section, with Explore beside it", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/security/reports/supply-chain")

      assert has_element?(view, "#header-sections a[aria-current=page]", "Reports")
      assert has_element?(view, "#header-sections a[href='/security']", "Explore")
      # Reports stays in this LiveView; Explore is another one.
      assert has_element?(view, "#header-sections a[data-phx-link=patch]", "Reports")
      assert has_element?(view, "#header-sections a[data-phx-link=redirect]", "Explore")
    end

    test "has no sidebar, so no button to toggle one", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/security/reports/supply-chain")

      refute has_element?(view, "button[phx-click='toggle_navigation']")
    end

    test "switching lens keeps the report shown", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/security/reports/supply-chain")

      view |> element("button[aria-label='Switch lens perspective']") |> render_click()
      view |> element("button[phx-value-lens-id='architect']") |> render_click()

      assert_patch(view, "/architect/reports/supply-chain")
    end
  end
end
