defmodule Clarity.Server.Worker do
  @moduledoc false

  use GenServer

  import Clarity.Telemetry, only: [report_work: 3]

  @type option() :: {:clarity_server, GenServer.server()}
  @type options() :: [option()]

  @enforce_keys [:clarity_server]
  defstruct [:clarity_server, :task, :async_task, :timeout_timer, :work_report]

  @type t() :: %__MODULE__{
          clarity_server: GenServer.server(),
          task: Clarity.Server.Task.t() | nil,
          async_task: Task.t() | nil,
          timeout_timer: reference() | nil,
          work_report:
            {Clarity.Telemetry.report_work_result_fun(),
             Clarity.Telemetry.report_work_result_fun()}
            | nil
        }

  @spec start_link(options()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl GenServer
  def init(opts) do
    clarity_server = Keyword.get(opts, :clarity_server, Clarity.Server)
    Clarity.subscribe(clarity_server, [:work_started, :work_completed, :__restart_pulling__])
    state = %__MODULE__{clarity_server: clarity_server}

    Process.flag(:trap_exit, true)
    Process.flag(:priority, :low)

    {:ok, state, {:continue, :pull_task}}
  end

  @impl GenServer
  # If not working on a task, try to pull one
  def handle_continue(:pull_task, %__MODULE__{clarity_server: clarity_server, task: nil} = state) do
    case Clarity.Server.pull_task(clarity_server) do
      {:ok, task} ->
        work_report = report_work(clarity_server, self(), task)

        async_task = Task.async(task.introspector, :introspect_vertex, [task.vertex, task.graph])
        timeout_timer = Process.send_after(self(), :timeout, to_timeout(second: 30))

        {:noreply,
         %{
           state
           | task: task,
             async_task: async_task,
             timeout_timer: timeout_timer,
             work_report: work_report
         }}

      :empty ->
        {:noreply, state, to_timeout(second: 1)}
    end
  end

  def handle_continue(:pull_task, _state) do
    raise "We should never get here, if you see this error, report a bug."
  end

  @impl GenServer
  # If not working on a task, try to pull one when notified of new work
  def handle_info(:timeout, %__MODULE__{task: nil} = state) do
    {:noreply, state, {:continue, :pull_task}}
  end

  # If not working on a task, try to pull one when notified of new work
  def handle_info({:clarity, _}, %__MODULE__{task: nil} = state) do
    {:noreply, state, {:continue, :pull_task}}
  end

  # If already working on a task, ignore new work notifications
  def handle_info({:clarity, _}, state) do
    {:noreply, state}
  end

  # Handle task results
  def handle_info(
        {ref, result},
        %__MODULE__{
          clarity_server: clarity_server,
          task: task,
          async_task: %Task{ref: ref},
          work_report: {report_result, report_exception}
        } = state
      ) do
    Process.cancel_timer(state.timeout_timer)

    case result do
      {:ok, entries} ->
        report_result.(entries)

        Clarity.Server.ack_task(clarity_server, task.id, entries)

      {:error, :unmet_dependencies} ->
        report_result.(:unmet_dependencies)

        Clarity.Server.requeue_task(clarity_server, task.id)

      {:error, reason} = error ->
        {:current_stacktrace, stacktrace} = Process.info(self(), :current_stacktrace)
        report_exception.(:error, reason, stacktrace)

        Clarity.Server.nack_task(clarity_server, task.id, error)

      unexpected_response ->
        reason = {:unexpected_response, unexpected_response}

        {:current_stacktrace, stacktrace} = Process.info(self(), :current_stacktrace)
        report_exception.(:error, reason, stacktrace)

        Clarity.Server.nack_task(clarity_server, task.id, {:error, reason})
    end

    {:noreply, %{state | task: nil, async_task: nil, timeout_timer: nil, work_report: nil},
     {:continue, :pull_task}}
  end

  # Handle task failures
  def handle_info({:EXIT, _pid, _error}, state) do
    # Handled by :DOWN message
    {:noreply, state}
  end

  # Handle task normal exit
  def handle_info({:DOWN, _ref, _fun, _pid, :normal}, state) do
    # Handled by result message
    {:noreply, state}
  end

  # Handle task crashes
  def handle_info(
        {:DOWN, ref, _fun, pid, reason},
        %__MODULE__{
          clarity_server: clarity_server,
          task: task,
          async_task: %Task{ref: ref, pid: pid},
          work_report: {_report_result, report_exception}
        } = state
      ) do
    Process.cancel_timer(state.timeout_timer)
    Clarity.Server.nack_task(clarity_server, task.id, reason)

    {:current_stacktrace, stacktrace} = Process.info(self(), :current_stacktrace)
    report_exception.(:exit, reason, stacktrace)

    {:noreply, %{state | task: nil, async_task: nil, timeout_timer: nil, work_report: nil},
     {:continue, :pull_task}}
  end

  # Task timed out
  def handle_info(
        :timeout,
        %__MODULE__{
          clarity_server: clarity_server,
          task: task,
          async_task: async_task,
          work_report: {_report_result, report_exception}
        } = state
      ) do
    Clarity.Server.nack_task(clarity_server, task.id, :timeout)
    Task.shutdown(async_task)

    {:current_stacktrace, stacktrace} = Process.info(self(), :current_stacktrace)
    report_exception.(:error, :timeout, stacktrace)

    {:noreply, %{state | task: nil, async_task: nil, timeout_timer: nil, work_report: nil},
     {:continue, :pull_task}}
  end
end
