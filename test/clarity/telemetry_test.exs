# credo:disable-for-this-file Credo.Check.Warning.UnsafeToAtom
defmodule Clarity.TelemetryTest do
  use ExUnit.Case, async: true

  alias Clarity.Server.Task
  alias Clarity.Server.Worker
  alias Clarity.Telemetry
  alias Clarity.Test.MockClarityServer
  alias Clarity.Vertex.Application, as: ApplicationVertex
  alias Clarity.Vertex.Root

  setup do
    test_pid = self()
    handler_id = "test-#{System.unique_integer([:positive])}"

    :telemetry.attach_many(
      handler_id,
      [
        [:clarity, :introspection, :start],
        [:clarity, :introspection, :progress],
        [:clarity, :introspection, :stop],
        [:clarity, :worker, :start],
        [:clarity, :worker, :stop],
        [:clarity, :worker, :exception]
      ],
      fn event, measurements, metadata, _config ->
        send(test_pid, {:telemetry, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    :ok
  end

  describe "introspection events" do
    test "emits start event on work_started" do
      mock_server = start_supervised!({MockClarityServer, self()})
      telemetry_pid = start_supervised!({Telemetry, clarity_server: mock_server})

      send(telemetry_pid, {:clarity, :work_started})

      assert_receive {:telemetry, [:clarity, :introspection, :start], measurements, metadata}
      assert %{monotonic_time: _, system_time: _} = measurements
      assert %{clarity_server: ^mock_server, telemetry_span_context: ref} = metadata
      assert is_reference(ref)
    end

    test "emits progress event on work_progress" do
      mock_server = start_supervised!({MockClarityServer, self()})
      telemetry_pid = start_supervised!({Telemetry, clarity_server: mock_server})

      queue_info = %{future_queue: 5, requeue_queue: 2, in_progress: 3, total_vertices: 10}
      send(telemetry_pid, {:clarity, {:work_progress, queue_info}})

      assert_receive {:telemetry, [:clarity, :introspection, :progress], measurements, metadata}

      assert %{
               duration: _,
               monotonic_time: _,
               system_time: _,
               future_queue: 5,
               requeue_queue: 2,
               in_progress: 3,
               total_vertices: 10
             } = measurements

      assert %{clarity_server: ^mock_server, telemetry_span_context: _} = metadata
    end

    test "emits stop event on work_completed" do
      mock_server = start_supervised!({MockClarityServer, self()})
      telemetry_pid = start_supervised!({Telemetry, clarity_server: mock_server})

      send(telemetry_pid, {:clarity, :work_completed})

      assert_receive {:telemetry, [:clarity, :introspection, :stop], measurements, metadata}
      assert %{duration: _, monotonic_time: _, system_time: _} = measurements
      assert %{clarity_server: ^mock_server, telemetry_span_context: _} = metadata
    end
  end

  describe "worker events" do
    defmodule SuccessfulIntrospector do
      @moduledoc false
      @behaviour Clarity.Introspector

      @impl Clarity.Introspector
      def source_vertex_types, do: [Root]

      @impl Clarity.Introspector
      def introspect_vertex(_vertex, _graph), do: {:ok, []}
    end

    defmodule SuccessfulWithEntriesIntrospector do
      @moduledoc false
      @behaviour Clarity.Introspector

      @impl Clarity.Introspector
      def source_vertex_types, do: [Root]

      @impl Clarity.Introspector
      def introspect_vertex(_vertex, _graph) do
        {:ok, [{:vertex, %ApplicationVertex{app: :test_app, description: "Test", version: "1.0.0"}}]}
      end
    end

    defmodule UnmetDependenciesIntrospector do
      @moduledoc false
      @behaviour Clarity.Introspector

      @impl Clarity.Introspector
      def source_vertex_types, do: [Root]

      @impl Clarity.Introspector
      def introspect_vertex(_vertex, _graph), do: {:error, :unmet_dependencies}
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

    test "emits start and stop events for successful task processing" do
      mock_server = start_supervised!({MockClarityServer, self()})

      graph = Clarity.Graph.new()
      task = Task.new_introspection(%Root{}, SuccessfulIntrospector, graph)

      start_supervised!({Worker, clarity_server: mock_server})

      assert_receive :pull_task
      send(mock_server, {:reply_pull_task, {:ok, task}})

      assert_receive {:telemetry, [:clarity, :worker, :start], start_measurements, start_metadata}
      assert %{monotonic_time: _, system_time: _} = start_measurements

      assert %{
               clarity_server: ^mock_server,
               worker: _worker,
               telemetry_span_context: ref,
               introspector: SuccessfulIntrospector,
               vertex_type: Root
             } = start_metadata

      assert is_reference(ref)

      assert_receive {:telemetry, [:clarity, :worker, :stop], stop_measurements, stop_metadata}

      assert %{
               duration: _,
               monotonic_time: _,
               system_time: _,
               result_entry_count: 0
             } = stop_measurements

      assert %{
               clarity_server: ^mock_server,
               telemetry_span_context: ^ref,
               introspector: SuccessfulIntrospector,
               vertex_type: Root,
               result_type: :ok
             } = stop_metadata

      assert_receive {:ack_task, _, []}
    end

    test "includes entry count in stop event" do
      mock_server = start_supervised!({MockClarityServer, self()})

      graph = Clarity.Graph.new()
      task = Task.new_introspection(%Root{}, SuccessfulWithEntriesIntrospector, graph)

      start_supervised!({Worker, clarity_server: mock_server})

      assert_receive :pull_task
      send(mock_server, {:reply_pull_task, {:ok, task}})

      assert_receive {:telemetry, [:clarity, :worker, :start], _, _}

      assert_receive {:telemetry, [:clarity, :worker, :stop], measurements, metadata}
      assert %{result_entry_count: 1} = measurements
      assert %{result_type: :ok} = metadata

      assert_receive {:ack_task, _, result}
      assert length(result) == 1
    end

    test "tracks unmet dependencies result type" do
      mock_server = start_supervised!({MockClarityServer, self()})

      graph = Clarity.Graph.new()
      task = Task.new_introspection(%Root{}, UnmetDependenciesIntrospector, graph)

      start_supervised!({Worker, clarity_server: mock_server})

      assert_receive :pull_task
      send(mock_server, {:reply_pull_task, {:ok, task}})

      assert_receive {:telemetry, [:clarity, :worker, :start], _, _}

      assert_receive {:telemetry, [:clarity, :worker, :stop], measurements, metadata}
      assert %{result_entry_count: nil} = measurements
      assert %{result_type: :unmet_dependencies} = metadata

      assert_receive {:requeue_task, _}
    end

    test "emits exception event when task processing fails" do
      mock_server = start_supervised!({MockClarityServer, self()})

      graph = Clarity.Graph.new()
      task = Task.new_introspection(%Root{}, FailingIntrospector, graph)

      start_supervised!({Worker, clarity_server: mock_server})

      assert_receive :pull_task
      send(mock_server, {:reply_pull_task, {:ok, task}})

      assert_receive {:telemetry, [:clarity, :worker, :start], _, start_metadata}
      ref = start_metadata.telemetry_span_context

      assert_receive {:telemetry, [:clarity, :worker, :exception], measurements, metadata}
      assert %{duration: _, monotonic_time: _, system_time: _} = measurements

      assert %{
               clarity_server: ^mock_server,
               telemetry_span_context: ^ref,
               introspector: FailingIntrospector,
               vertex_type: Root,
               kind: :exit,
               reason: {%RuntimeError{message: "Intentional test error"}, _},
               stacktrace: stacktrace
             } = metadata

      assert is_list(stacktrace)

      assert_receive {:nack_task, _, {%RuntimeError{message: "Intentional test error"}, _}}
    end
  end
end
