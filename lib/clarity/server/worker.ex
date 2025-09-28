defmodule Clarity.Server.Worker do
  @moduledoc false

  use GenServer

  @type option() :: {:clarity_server, GenServer.server()}
  @type options() :: [option()]

  @enforce_keys [:clarity_server]
  defstruct [:clarity_server, :task, :async_task, :timeout_timer]

  @type t() :: %__MODULE__{
          clarity_server: GenServer.server(),
          task: Clarity.Server.Task.t() | nil,
          async_task: Task.t() | nil,
          timeout_timer: reference() | nil
        }

  @spec start_link(options()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl GenServer
  def init(opts) do
    clarity_server = Keyword.get(opts, :clarity_server, Clarity.Server)
    Clarity.subscribe(clarity_server)
    state = %__MODULE__{clarity_server: clarity_server}

    Process.flag(:trap_exit, true)

    {:ok, state, {:continue, :pull_task}}
  end

  @impl GenServer
  # If not working on a task, try to pull one
  def handle_continue(:pull_task, %__MODULE__{clarity_server: clarity_server, task: nil} = state) do
    case Clarity.Server.pull_task(clarity_server) do
      {:ok, task} ->
        async_task = Task.async(task.introspector, :introspect_vertex, [task.vertex, task.graph])
        timeout_timer = Process.send_after(self(), :timeout, to_timeout(second: 30))

        {:noreply, %{state | task: task, async_task: async_task, timeout_timer: timeout_timer}}

      :empty ->
        # No dynamic subscription needed - we're always subscribed
        # Just hibernate until we receive :work_started event
        {:noreply, state, :hibernate}
    end
  end

  def handle_continue(:pull_task, _state) do
    raise "We should never get here, if you see this error, report a bug."
  end

  @impl GenServer
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
        %__MODULE__{clarity_server: clarity_server, task: task, async_task: %Task{ref: ref}} =
          state
      ) do
    Process.cancel_timer(state.timeout_timer)

    case result do
      {:ok, entries} ->
        Clarity.Server.ack_task(clarity_server, task.id, entries)

      {:error, :unmet_dependencies} ->
        Clarity.Server.requeue_task(clarity_server, task.id)

      {:error, _reason} = error ->
        Clarity.Server.nack_task(clarity_server, task.id, error)

      unexpected_response ->
        Clarity.Server.nack_task(clarity_server, task.id, {:error, unexpected_response})
    end

    {:noreply, %{state | task: nil, async_task: nil, timeout_timer: nil}, {:continue, :pull_task}}
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
          async_task: %Task{ref: ref, pid: pid}
        } = state
      ) do
    Process.cancel_timer(state.timeout_timer)
    Clarity.Server.nack_task(clarity_server, task.id, reason)
    {:noreply, %{state | task: nil, async_task: nil, timeout_timer: nil}, {:continue, :pull_task}}
  end

  # Task timed out
  def handle_info(
        :timeout,
        %__MODULE__{clarity_server: clarity_server, task: task, async_task: async_task} = state
      ) do
    Clarity.Server.nack_task(clarity_server, task.id, :timeout)
    Task.shutdown(async_task)
    {:noreply, %{state | task: nil, async_task: nil, timeout_timer: nil}, {:continue, :pull_task}}
  end
end
