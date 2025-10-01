defmodule Clarity.Server.WorkerTest do
  use ExUnit.Case, async: true

  alias Clarity.Server.Task
  alias Clarity.Server.Worker
  alias Clarity.Vertex.Root

  defmodule MockClarityServer do
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

  describe "Worker task execution" do
    test "pulls and executes tasks successfully" do
      mock_server = start_supervised!({MockClarityServer, self()})

      # Create a sample task with graph
      graph = Clarity.Graph.new()
      task = Task.new_introspection(%Root{}, Clarity.Introspector.Application, graph)

      # Start worker with our mock server
      start_supervised!({Worker, clarity_server: mock_server})

      # Worker should immediately try to pull a task
      assert_receive :pull_task

      # Respond with our test task
      send(mock_server, {:reply_pull_task, {:ok, task}})

      # Worker should acknowledge task completion (no longer needs to get graph)
      assert_receive {:ack_task, task_id, result}
      assert task_id == task.id
      assert is_list(result)

      # Worker should try to pull another task
      assert_receive :pull_task
    end

    test "handles empty queue by subscribing and hibernating" do
      mock_server = start_supervised!({MockClarityServer, self()})

      worker_pid = start_supervised!({Worker, clarity_server: mock_server})

      # Worker should subscribe immediately on init
      assert_receive :subscribe

      # Worker tries to pull a task
      assert_receive :pull_task
      send(mock_server, {:reply_pull_task, :empty})

      # Worker should now be hibernating - send work_started event to wake up
      send(worker_pid, {:clarity, :work_started})

      # Worker should try to pull task again (no unsubscribe since we never unsubscribe)
      assert_receive :pull_task
    end

    test "ignores other clarity events when subscribed" do
      mock_server = start_supervised!({MockClarityServer, self()})

      worker_pid = start_supervised!({Worker, clarity_server: mock_server})

      # Worker subscribes immediately on init
      assert_receive :subscribe

      # Get worker to hibernate
      assert_receive :pull_task
      # Let pull_task timeout to :empty

      # Send other clarity events - worker should ignore them and stay hibernating
      send(worker_pid, {:clarity, :some_other_event})
      send(worker_pid, {:clarity, {:work_progress, %{}}})

      # Should not pull tasks for non-work_started events
      refute_receive :pull_task, 50
    end

    test "handles task execution errors with nack_task" do
      defmodule FailingIntrospector do
        @moduledoc false
        @behaviour Clarity.Introspector

        @impl Clarity.Introspector
        def source_vertex_types, do: [Root]

        @impl Clarity.Introspector
        def introspect_vertex(_vertex, _graph) do
          raise "Intentional test error"
        end
      end

      mock_server = start_supervised!({MockClarityServer, self()})

      # Create a task with an introspector that will fail
      graph = Clarity.Graph.new()
      task = Task.new_introspection(%Root{}, FailingIntrospector, graph)
      task_id = task.id

      worker = start_supervised!({Worker, clarity_server: mock_server})

      # Wake up worker to pull task
      send(worker, {:clarity, :work_started})

      # Worker pulls task
      assert_receive :pull_task
      send(mock_server, {:reply_pull_task, {:ok, task}})

      # Worker should nack the task due to execution error
      assert_receive {:nack_task, ^task_id, {%RuntimeError{message: "Intentional test error"}, _stacktrace}},
                     to_timeout(second: 1)
    end
  end
end
