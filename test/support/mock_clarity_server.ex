defmodule Clarity.Test.MockClarityServer do
  @moduledoc false
  use GenServer

  @spec start_link(pid()) :: GenServer.on_start()
  def start_link(test_pid) do
    GenServer.start_link(__MODULE__, test_pid)
  end

  @spec enqueue_pull_task(GenServer.server(), term()) :: :ok
  def enqueue_pull_task(mock, response) do
    GenServer.call(mock, {:enqueue_pull_task, response})
  end

  @impl GenServer
  def init(test_pid) do
    {:ok, %{test_pid: test_pid, pull_task_queue: :queue.new()}}
  end

  @impl GenServer
  def handle_call(:pull_task, _from, state) do
    send(state.test_pid, :pull_task)

    case :queue.out(state.pull_task_queue) do
      {{:value, response}, queue} ->
        {:reply, response, %{state | pull_task_queue: queue}}

      {:empty, _queue} ->
        {:reply, :empty, state}
    end
  end

  def handle_call({:enqueue_pull_task, response}, _from, state) do
    queue = :queue.in(response, state.pull_task_queue)
    {:reply, :ok, %{state | pull_task_queue: queue}}
  end

  def handle_call(:get, _from, state) do
    send(state.test_pid, :get)

    clarity = %Clarity{
      graph: Clarity.Graph.new(),
      status: :done,
      queue_info: %{future_queue: 0, in_progress: 0, total_vertices: 0, requeue_queue: 0}
    }

    {:reply, clarity, state}
  end

  def handle_call(:subscribe, _from, state) do
    send(state.test_pid, :subscribe)
    unsubscribe_fn = fn -> send(state.test_pid, :unsubscribed) end
    {:reply, unsubscribe_fn, state}
  end

  @impl GenServer
  def handle_cast({:ack_task, task_id, result}, state) do
    send(state.test_pid, {:ack_task, task_id, result})
    {:noreply, state}
  end

  def handle_cast({:nack_task, task_id, error}, state) do
    send(state.test_pid, {:nack_task, task_id, error})
    {:noreply, state}
  end

  def handle_cast({:requeue_task, task_id}, state) do
    send(state.test_pid, {:requeue_task, task_id})
    {:noreply, state}
  end

  def handle_cast({:introspect, scope}, state) do
    send(state.test_pid, {:introspect, scope})
    {:noreply, state}
  end
end
