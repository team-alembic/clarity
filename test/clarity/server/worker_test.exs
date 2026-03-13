defmodule Clarity.Server.WorkerTest do
  use ExUnit.Case, async: true

  alias Clarity.Server.Task
  alias Clarity.Server.Worker
  alias Clarity.Test.MockClarityServer
  alias Clarity.Vertex.Root

  describe "Worker task execution" do
    test "pulls and executes tasks successfully" do
      mock_server = start_supervised!({MockClarityServer, self()})

      graph = Clarity.Graph.new()
      task = Task.new_introspection(%Root{}, Clarity.Introspector.Application, graph)

      MockClarityServer.enqueue_pull_task(mock_server, {:ok, task})
      start_supervised!({Worker, clarity_server: mock_server})

      assert_receive {:ack_task, task_id, result}
      assert task_id == task.id
      assert is_list(result)
    end

    test "handles empty queue by subscribing and hibernating" do
      mock_server = start_supervised!({MockClarityServer, self()})

      worker_pid = start_supervised!({Worker, clarity_server: mock_server})

      # Worker pulls, gets :empty (queue is empty), goes idle
      assert_receive :pull_task

      # Wake worker - it should pull again
      send(worker_pid, {:clarity, :work_started})

      assert_receive :pull_task
    end

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

    test "handles task execution errors with nack_task" do
      mock_server = start_supervised!({MockClarityServer, self()})

      graph = Clarity.Graph.new()
      task = Task.new_introspection(%Root{}, FailingIntrospector, graph)
      task_id = task.id

      MockClarityServer.enqueue_pull_task(mock_server, {:ok, task})
      start_supervised!({Worker, clarity_server: mock_server})

      assert_receive {:nack_task, ^task_id, {%RuntimeError{message: "Intentional test error"}, _stacktrace}},
                     500
    end
  end
end
