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

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="flex items-center space-x-2">
      <div
        :if={@work_status == :working}
        class="flex items-center space-x-3 px-4 py-2 bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-md"
        title={"Vertices: #{@queue_info.total_vertices} | In Progress: #{@queue_info.in_progress} | Queued: #{@queue_info.future_queue} | Requeued: #{@queue_info.requeue_queue}"}
      >
        <progress
          value={@queue_info.total_vertices}
          max={
            @queue_info.total_vertices + @queue_info.future_queue + @queue_info.in_progress +
              @queue_info.requeue_queue
          }
          class="w-32 h-4 [&::-webkit-progress-bar]:rounded-full [&::-webkit-progress-bar]:bg-blue-200 dark:[&::-webkit-progress-bar]:bg-blue-700 [&::-webkit-progress-value]:rounded-full [&::-webkit-progress-value]:bg-blue-600 dark:[&::-webkit-progress-value]:bg-blue-400 [&::-moz-progress-bar]:rounded-full [&::-moz-progress-bar]:bg-blue-600 dark:[&::-moz-progress-bar]:bg-blue-400"
        >
        </progress>
      </div>

      <button
        type="button"
        disabled={@work_status == :working}
        phx-click="refresh"
        class="inline-flex items-center justify-center p-2 rounded-md text-base-light-600 dark:text-base-dark-400 hover:text-base-light-900 dark:hover:text-base-dark-100 hover:bg-base-light-200 dark:hover:bg-base-dark-700 focus:outline-hidden focus:ring-2 focus:ring-primary-light dark:focus:ring-primary-dark transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        aria-label="Refresh"
      >
        <svg
          class={"w-5 h-5 #{if @work_status == :working, do: "animate-spin", else: ""}"}
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
          />
        </svg>
      </button>
    </div>
    """
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
