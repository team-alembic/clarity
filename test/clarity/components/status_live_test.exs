defmodule Clarity.Components.StatusLiveTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Clarity.Components.StatusLive
  alias Clarity.Test.MockClarityServer

  @endpoint DemoWeb.Endpoint

  setup do
    {:ok, mock_pid} = MockClarityServer.start_link(self())
    conn = Phoenix.ConnTest.build_conn()

    {:ok, conn: conn, mock_pid: mock_pid}
  end

  describe "StatusLive Initial State" do
    test "mounts successfully", %{conn: conn, mock_pid: mock_pid} do
      {:ok, view, _html} = live_isolated(conn, StatusLive, session: %{"clarity_pid" => mock_pid})

      assert view
    end

    test "renders refresh button without progress bar", %{conn: conn, mock_pid: mock_pid} do
      {:ok, view, _html} = live_isolated(conn, StatusLive, session: %{"clarity_pid" => mock_pid})

      refute has_element?(view, "button[phx-click='refresh'][disabled]")
      assert has_element?(view, "button[phx-click='refresh']")
      refute has_element?(view, "progress")
    end
  end

  describe "StatusLive Work Started Event" do
    test "displays progress bar and disables refresh button", %{conn: conn, mock_pid: mock_pid} do
      {:ok, view, _html} = live_isolated(conn, StatusLive, session: %{"clarity_pid" => mock_pid})

      send(view.pid, {:clarity, :work_started})

      html = render(view)

      assert has_element?(view, "progress")
      assert has_element?(view, "button[phx-click='refresh'][disabled]")
      assert html =~ "animate-spin"
    end
  end

  describe "StatusLive Work Progress Event" do
    test "displays progress bar with correct values", %{conn: conn, mock_pid: mock_pid} do
      {:ok, view, _html} = live_isolated(conn, StatusLive, session: %{"clarity_pid" => mock_pid})

      send(view.pid, {:clarity, :work_started})

      queue_info = %{
        total_vertices: 10,
        future_queue: 5,
        in_progress: 2,
        requeue_queue: 1
      }

      send(view.pid, {:clarity, {:work_progress, queue_info}})

      html = render(view)

      assert html =~ ~s[value="10"]
      assert html =~ ~s[max="18"]
      assert html =~ "Vertices: 10"
      assert html =~ "In Progress: 2"
      assert html =~ "Queued: 5"
      assert html =~ "Requeued: 1"
    end
  end

  describe "StatusLive Throttle Mechanism" do
    test "throttle tick processes pending progress", %{conn: conn, mock_pid: mock_pid} do
      {:ok, view, _html} = live_isolated(conn, StatusLive, session: %{"clarity_pid" => mock_pid})

      send(view.pid, {:clarity, :work_started})
      render(view)

      queue_info1 = %{total_vertices: 10, future_queue: 5, in_progress: 2, requeue_queue: 1}
      send(view.pid, {:clarity, {:work_progress, queue_info1}})
      render(view)

      queue_info2 = %{total_vertices: 15, future_queue: 3, in_progress: 1, requeue_queue: 0}
      send(view.pid, {:clarity, {:work_progress, queue_info2}})
      render(view)

      Process.sleep(60)
      html = render(view)

      assert html =~ ~s[value="15"]
      assert html =~ ~s[max="19"]
    end
  end

  describe "StatusLive Work Completed Event" do
    test "hides progress bar and re-enables refresh button", %{conn: conn, mock_pid: mock_pid} do
      {:ok, view, _html} = live_isolated(conn, StatusLive, session: %{"clarity_pid" => mock_pid})

      send(view.pid, {:clarity, :work_started})
      render(view)

      send(view.pid, {:clarity, :work_completed})
      html = render(view)

      refute has_element?(view, "progress")
      refute has_element?(view, "button[phx-click='refresh'][disabled]")
      assert has_element?(view, "button[phx-click='refresh']")
      refute html =~ "animate-spin"
    end
  end

  describe "StatusLive Refresh Button" do
    test "clicking refresh button calls introspect", %{conn: conn, mock_pid: mock_pid} do
      {:ok, view, _html} = live_isolated(conn, StatusLive, session: %{"clarity_pid" => mock_pid})

      view |> element("button[phx-click='refresh']") |> render_click()

      assert_receive {:introspect, :full}
    end

    test "refresh button remains enabled after click", %{conn: conn, mock_pid: mock_pid} do
      {:ok, view, _html} = live_isolated(conn, StatusLive, session: %{"clarity_pid" => mock_pid})

      view |> element("button[phx-click='refresh']") |> render_click()

      refute has_element?(view, "button[phx-click='refresh'][disabled]")
      assert has_element?(view, "button[phx-click='refresh']")
    end
  end

  describe "StatusLive UI State Transitions" do
    test "transitions from done to working to done", %{conn: conn, mock_pid: mock_pid} do
      {:ok, view, _html} = live_isolated(conn, StatusLive, session: %{"clarity_pid" => mock_pid})

      refute has_element?(view, "progress")
      refute has_element?(view, "button[phx-click='refresh'][disabled]")

      send(view.pid, {:clarity, :work_started})
      html = render(view)

      assert has_element?(view, "progress")
      assert has_element?(view, "button[phx-click='refresh'][disabled]")
      assert html =~ "animate-spin"

      send(view.pid, {:clarity, :work_completed})
      html = render(view)

      refute has_element?(view, "progress")
      refute has_element?(view, "button[phx-click='refresh'][disabled]")
      refute html =~ "animate-spin"
    end

    test "progress bar appears and updates during work", %{conn: conn, mock_pid: mock_pid} do
      {:ok, view, _html} = live_isolated(conn, StatusLive, session: %{"clarity_pid" => mock_pid})

      send(view.pid, {:clarity, :work_started})
      render(view)

      queue_info1 = %{total_vertices: 5, future_queue: 10, in_progress: 2, requeue_queue: 0}
      send(view.pid, {:clarity, {:work_progress, queue_info1}})
      html = render(view)

      assert html =~ ~s[value="5"]
      assert html =~ ~s[max="17"]

      Process.sleep(60)

      queue_info2 = %{total_vertices: 10, future_queue: 5, in_progress: 1, requeue_queue: 1}
      send(view.pid, {:clarity, {:work_progress, queue_info2}})

      Process.sleep(60)
      html = render(view)

      assert html =~ ~s[value="10"]
      assert html =~ ~s[max="17"]
    end
  end
end
