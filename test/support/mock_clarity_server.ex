defmodule Clarity.Test.MockClarityServer do
  @moduledoc false
  use GenServer

  @spec start_link(pid()) :: GenServer.on_start()
  def start_link(test_pid) do
    GenServer.start_link(__MODULE__, test_pid)
  end

  @impl GenServer
  def init(test_pid) do
    {:ok, %{test_pid: test_pid}}
  end

  @impl GenServer
  def handle_call(:pull_task, _from, state) do
    send(state.test_pid, :pull_task)

    receive do
      {:reply_pull_task, response} -> {:reply, response, state}
    after
      1000 -> {:reply, :empty, state}
    end
  end

  def handle_call(:get, _from, state) do
    send(state.test_pid, :get)

    receive do
      {:reply_get, response} -> {:reply, response, state}
    after
      1000 ->
        clarity = %Clarity{
          graph: Clarity.Graph.new(),
          status: :done,
          queue_info: %{future_queue: 0, in_progress: 0, total_vertices: 0}
        }

        {:reply, clarity, state}
    end
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
end
