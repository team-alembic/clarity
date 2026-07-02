defmodule Clarity.ReportLiveTest do
  use Clarity.Test.ConnCase, async: true

  describe "ReportLive" do
    test "renders the supply-chain report under the security lens", %{conn: conn} do
      {:ok, view, html} = live(conn, "/security/report/supply-chain")

      assert html =~ "Supply chain security"
      # the report picker lists the lens's other report too
      assert html =~ "Security posture"
      # the Explore | Reports toggle
      assert has_element?(view, "a", "Explore")
      assert has_element?(view, "a", "Reports")
    end

    test "renders the security posture report", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/security/report/security-posture")

      assert html =~ "Security posture"
    end

    test "switching report tabs patches to the other report", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/security/report/supply-chain")

      html = view |> element("a", "Security posture") |> render_click()

      assert html =~ "Security posture"
    end

    test "shows an empty state for a lens with no reports", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/architect/report")

      assert html =~ "No reports are available"
    end
  end
end
