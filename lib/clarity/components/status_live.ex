defmodule Clarity.Components.StatusLive do
  @moduledoc false
  use Clarity.Web, :live_view

  alias Phoenix.LiveView.Socket

  @impl Phoenix.LiveView
  def mount(_params, %{"clarity_pid" => clarity_pid}, socket) do
    Clarity.subscribe(
      clarity_pid,
      [:work_progress, :work_started, :work_completed]
    )

    {:ok,
     socket
     |> assign(:clarity_pid, clarity_pid)
     |> assign(:work_status, :done)
     |> assign(:queue_info, %{
       total_vertices: 0,
       future_queue: 0,
       in_progress: 0,
       requeue_queue: 0
     })
     |> assign(:throttle_timer, nil)
     |> assign(:pending_progress, nil)}
  end

  @impl Phoenix.LiveView
  def handle_info({:clarity, :work_started}, socket) do
    {:noreply, assign(socket, :work_status, :working)}
  end

  @impl Phoenix.LiveView
  def handle_info({:clarity, :work_completed}, socket) do
    socket = cancel_throttle_timer(socket)

    {:noreply,
     socket
     |> assign(:work_status, :done)
     |> assign(:pending_progress, nil)}
  end

  @impl Phoenix.LiveView
  def handle_info({:clarity, {:work_progress, queue_info}}, socket) do
    socket =
      if is_nil(socket.assigns.throttle_timer) do
        timer = Process.send_after(self(), :throttle_tick, 50)

        socket
        |> assign(:queue_info, queue_info)
        |> assign(:throttle_timer, timer)
        |> assign(:pending_progress, nil)
      else
        assign(socket, :pending_progress, queue_info)
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info(:throttle_tick, socket) do
    socket = assign(socket, :throttle_timer, nil)

    socket =
      if socket.assigns.pending_progress do
        timer = Process.send_after(self(), :throttle_tick, 50)

        socket
        |> assign(:queue_info, socket.assigns.pending_progress)
        |> assign(:pending_progress, nil)
        |> assign(:throttle_timer, timer)
      else
        socket
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("refresh", _params, socket) do
    Clarity.introspect(socket.assigns.clarity_pid)
    {:noreply, socket}
  end

  @spec cancel_throttle_timer(Socket.t()) :: Socket.t()
  defp cancel_throttle_timer(socket) do
    if socket.assigns.throttle_timer do
      Process.cancel_timer(socket.assigns.throttle_timer)
      assign(socket, :throttle_timer, nil)
    else
      socket
    end
  end
end
