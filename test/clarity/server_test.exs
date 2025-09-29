# credo:disable-for-this-file Credo.Check.Warning.UnsafeToAtom
defmodule Clarity.ServerTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Clarity.Server
  alias Clarity.Server.Worker
  alias Clarity.Test.DummyIntrospector
  alias Clarity.Vertex.Application
  alias Clarity.Vertex.Module, as: ModuleVertex
  alias Clarity.Vertex.Root

  describe "Server initialization and basic operations" do
    test "starts with root vertex and initial tasks queued", %{test: test} do
      server = start_supervised!({Server, name: Module.concat(__MODULE__, test)})

      # Get initial state
      clarity = Clarity.get(server, :partial)

      assert [%Root{}] = Clarity.Graph.vertices(clarity.graph)

      # Should be able to pull initial task (only Application introspector handles Root)
      assert {:ok, task1} = Server.pull_task(server)

      # Task should be for root vertex with Application introspector
      assert task1.vertex == %Root{}
      assert task1.introspector == Clarity.Introspector.Application

      # No more tasks should be available for root vertex
      assert :empty = Server.pull_task(server)
    end

    test "handles empty queue when no more tasks available", %{test: test} do
      server = start_supervised!({Server, name: Module.concat(__MODULE__, test)})

      # Pull all available tasks
      tasks = pull_all_tasks(server)
      assert length(tasks) > 0

      # Next pull should return empty
      assert :empty = Server.pull_task(server)
    end

    test "tracks tasks in progress correctly", %{test: test} do
      server = start_supervised!({Server, name: Module.concat(__MODULE__, test)})

      # Pull the first (root) task with worker1
      assert {:ok, task1} = Server.pull_task(server)

      # Process task1 to create more vertices/tasks
      app_vertex = %ModuleVertex{module: __MODULE__}
      Server.ack_task(server, task1.id, [{:vertex, app_vertex}])

      # Force synchronization since ack_task is async
      Clarity.get(server, :partial)

      assert {:ok, task2} = Server.pull_task(server)
      assert {:ok, _task3} = Server.pull_task(server)

      # Tasks should be tracked in progress
      # We can verify this indirectly by acking with wrong worker
      assert :ok = Server.nack_task(server, task2.id, :test_error)

      # task2 should still be in progress for worker1
      assert :ok = Server.ack_task(server, task2.id, [])
    end

    test "vertex type filtering creates only relevant tasks", %{test: test} do
      server = start_supervised!({Server, name: Module.concat(__MODULE__, test)})

      # Initially should only have 1 task for Root vertex (Application introspector)
      assert {:ok, root_task} = Server.pull_task(server)
      assert root_task.introspector == Clarity.Introspector.Application
      assert :empty = Server.pull_task(server)

      app_vertex = %Application{app: :kernel, description: "Kernel", version: "1.0.0"}
      Server.ack_task(server, root_task.id, [{:vertex, app_vertex}])

      # Force synchronization since ack_task is async
      Clarity.get(server, :partial)

      tasks = pull_all_tasks(server)
      assert length(tasks) == 1
      assert Enum.all?(tasks, &(&1.vertex == app_vertex))

      expected_introspectors = [
        Clarity.Introspector.Module
      ]

      actual_introspectors = Enum.map(tasks, & &1.introspector)
      assert Enum.sort(actual_introspectors) == Enum.sort(expected_introspectors)
    end
  end

  describe "Task processing and graph building" do
    test "processes task results and builds graph", %{test: test} do
      server = start_supervised!({Server, name: Module.concat(__MODULE__, test)})

      # Pull an Application introspector task
      {:ok, task} = find_task_for_introspector(server, Clarity.Introspector.Application)

      # Create mock result with new vertex and edge
      app_vertex = %Application{app: :test_app, description: "Test App", version: "1.0.0"}

      result = [
        {:vertex, app_vertex},
        {:edge, task.vertex, app_vertex, :application}
      ]

      # Ack the task with results
      assert :ok = Server.ack_task(server, task.id, result)

      # Verify graph was updated
      clarity = Clarity.get(server, :partial)
      app_vertex_id = Clarity.Vertex.unique_id(app_vertex)
      retrieved_app_vertex = Clarity.Graph.get_vertex(clarity.graph, app_vertex_id)
      assert retrieved_app_vertex == app_vertex

      # Verify edge was added
      edges = Clarity.Graph.edges(clarity.graph)
      assert length(edges) == 1
      [edge_id] = edges

      assert {^edge_id, root_vertex, ^app_vertex, :application} =
               Clarity.Graph.edge(clarity.graph, edge_id)

      assert root_vertex == task.vertex

      # Verify vertices were added to graph
      vertices = Clarity.Graph.vertices(clarity.graph)
      assert app_vertex in vertices
    end

    test "creates new tasks for newly added vertices", %{test: test} do
      server = start_supervised!({Server, name: Module.concat(__MODULE__, test)})

      # Pull and ack a task that creates a new vertex
      {:ok, task} = find_task_for_introspector(server, Clarity.Introspector.Application)

      app_vertex = %Application{app: :test_app, description: "Test App", version: "1.0.0"}

      result = [
        {:vertex, app_vertex},
        {:edge, task.vertex, app_vertex, :application}
      ]

      assert :ok = Server.ack_task(server, task.id, result)

      Clarity.get(server, :partial)
      app_task = find_task_for_vertex(server, app_vertex)
      assert app_task != :not_found
    end

    test "handles task failure with nack", %{test: test} do
      server = start_supervised!({Server, name: Module.concat(__MODULE__, test)})

      assert {:ok, task} = Server.pull_task(server)

      # Nack the task
      assert :ok = Server.nack_task(server, task.id, :test_error)

      # Task should no longer be in progress
      # Verify by trying to ack it - should succeed but do nothing
      assert :ok = Server.ack_task(server, task.id, [])
    end

    test "validates edge provenance and logs warnings for invalid edges", %{test: test} do
      server = start_supervised!({Server, name: Module.concat(__MODULE__, test)})

      # Pull a task
      assert {:ok, task} = Server.pull_task(server)

      # Create vertices for testing edge provenance
      valid_vertex = %Application{app: :valid_app, description: "Valid App", version: "1.0.0"}
      invalid_vertex = %Application{app: :invalid_app, description: "Invalid App", version: "1.0.0"}

      # Create a result with both valid and invalid edges
      result = [
        {:vertex, valid_vertex},
        # Valid edge: from causing vertex to created vertex
        {:edge, task.vertex, valid_vertex, :application},
        # Valid edge: from created vertex to another vertex
        {:edge, valid_vertex, task.vertex, :reverse},
        # Invalid edge: neither from nor to vertex is allowed
        {:edge, invalid_vertex, invalid_vertex, :invalid}
      ]

      # Capture logs to verify warning is logged for invalid edge
      log =
        capture_log(fn ->
          assert :ok = Server.ack_task(server, task.id, result)

          # Force synchronization since ack_task is async
          Clarity.get(server, :partial)
        end)

      # Should log warning about discarded invalid edge
      assert log =~ "Discarding invalid edge"
      assert log =~ "neither from_vertex"
      assert log =~ "nor to_vertex"
      assert log =~ "were created by this introspection"

      # Verify the valid vertex was added but invalid edge was discarded
      clarity = Clarity.get(server)
      vertices = Clarity.Graph.vertices(clarity.graph)
      assert valid_vertex in vertices

      # The valid edges should be present
      edges = Clarity.Graph.edges(clarity.graph)
      # At least the two valid edges we created
      assert length(edges) >= 2
    end
  end

  describe "Incremental introspection" do
    test "falls back to full introspection when introspector modules change", %{test: test} do
      server =
        start_supervised!({Server, name: Module.concat(__MODULE__, test), introspectors: [DummyIntrospector]})

      # Start a worker to process tasks
      _worker = start_supervised!({Worker, clarity_server: server})

      # Wait for initial work to complete
      initial_state = Clarity.get(server, :complete)
      assert initial_state.status == :done

      # Simulate an introspector module being changed
      modules_diff = %{
        # This is an introspector module
        changed: [DummyIntrospector],
        added: [],
        removed: []
      }

      # Capture logs to verify fallback message
      log =
        capture_log(fn ->
          assert :ok = Clarity.introspect(server, {:incremental, :clarity, modules_diff})
          # Wait for fallback introspection to complete
          final_state = Clarity.get(server, :complete)
          assert final_state.status == :done
        end)

      # Should log that it's falling back to full introspection
      assert log =~ "Introspector modules changed, falling back to full introspection"
    end

    test "Module.introspect_modules creates correct vertices and edges", %{test: _test} do
      # Test the new introspect_modules function directly
      graph = Clarity.Graph.new()
      app_vertex = %Application{app: :test_app, description: "Test App", version: "1.0.0"}
      modules = [String, Enum]

      results = Clarity.Introspector.Module.introspect_modules(app_vertex, modules, graph)

      # Should create vertices and edges for each module
      vertices = Enum.filter(results, &match?({:vertex, _}, &1))
      edges = Enum.filter(results, &match?({:edge, _, _, :module}, &1))

      # Should have at least one vertex per module
      assert length(vertices) >= length(modules)

      # Should have one edge per module connecting app to module
      assert length(edges) >= length(modules)

      # All module vertices should be for the specified modules
      module_vertices = Enum.map(vertices, fn {:vertex, v} -> v end)

      module_vertex_modules =
        module_vertices
        |> Enum.map(fn
          %ModuleVertex{module: m} -> m
          _ -> nil
        end)
        |> Enum.reject(&is_nil/1)

      Enum.each(modules, fn module ->
        assert module in module_vertex_modules
      end)
    end

    test "incremental introspection removes, changes and adds modules correctly", %{test: test} do
      # Create a test module at runtime to simulate real module addition
      test_module_name = Module.concat([TestDynamicModule, test])

      # Define the module at runtime
      defmodule TestDynamicModule do
        @moduledoc false
      end

      # Use clarity app for testing since we know it exists
      server =
        start_supervised!(
          {Server,
           name: Module.concat(__MODULE__, test),
           introspectors: [Clarity.Introspector.Application, Clarity.Introspector.Module]}
        )

      _worker = start_supervised!({Worker, clarity_server: server})

      # Wait for initial introspection to complete
      initial_state = Clarity.get(server, :complete)
      assert initial_state.status == :done

      # Add some initial modules manually so we have something to remove/change
      clarity_app = :clarity

      initial_modules_diff = %{
        changed: [],
        # Add these modules first
        added: [TestDynamicModule, String],
        removed: []
      }

      assert :ok = Clarity.introspect(server, {:incremental, clarity_app, initial_modules_diff})
      after_add_state = Clarity.get(server, :complete)
      assert after_add_state.status == :done

      # Verify modules were added
      after_add_vertices = Clarity.Graph.vertices(after_add_state.graph)
      after_add_modules = get_module_names_from_vertices(after_add_vertices)
      assert TestDynamicModule in after_add_modules
      assert String in after_add_modules

      # Now perform realistic incremental changes
      realistic_modules_diff = %{
        # This module changed, should be purged and re-added
        changed: [String],
        # New module added at runtime
        added: [test_module_name],
        # Remove the module we just added
        removed: [TestDynamicModule]
      }

      assert :ok = Clarity.introspect(server, {:incremental, clarity_app, realistic_modules_diff})
      final_state = Clarity.get(server, :complete)
      assert final_state.status == :done

      # Verify the incremental changes
      final_vertices = Clarity.Graph.vertices(final_state.graph)
      final_modules = get_module_names_from_vertices(final_vertices)

      # ASSERTIVE CHECKS:
      # 1. Removed module should be gone
      refute TestDynamicModule in final_modules, "TestDynamicModule should have been removed"

      # 2. Added module should be present
      assert test_module_name in final_modules, "#{test_module_name} should have been added"

      # 3. Changed module should still be present (purged and re-added)
      assert String in final_modules, "String should still be present after change"

      # 4. Verify edges exist for added/changed modules
      final_edges = Clarity.Graph.edges(final_state.graph)

      # Find the clarity app vertex
      clarity_app_vertex = Enum.find(final_vertices, &match?(%Application{app: :clarity}, &1))
      assert clarity_app_vertex, "Clarity app vertex should exist"

      # Check edges from app to modules
      app_to_module_edges =
        Enum.filter(final_edges, fn edge_id ->
          case Clarity.Graph.edge(final_state.graph, edge_id) do
            {_, ^clarity_app_vertex, %ModuleVertex{}, :module} -> true
            _ -> false
          end
        end)

      # Should have edges for changed and added modules
      app_to_module_edge_targets =
        Enum.map(app_to_module_edges, fn edge_id ->
          {_, _, %ModuleVertex{module: m}, :module} = Clarity.Graph.edge(final_state.graph, edge_id)
          m
        end)

      assert String in app_to_module_edge_targets, "Should have edge from app to String module"
      assert test_module_name in app_to_module_edge_targets, "Should have edge from app to #{test_module_name} module"
      refute TestDynamicModule in app_to_module_edge_targets, "Should NOT have edge to removed TestDynamicModule"

      # 5. Verify vertex counts make sense
      initial_count = length(get_module_names_from_vertices(after_add_vertices))
      final_count = length(final_modules)

      # We removed 1 module, added 1 module, changed 1 module -> net should be same count
      # (change = remove + add, so -1 +1 +0 = 0 net change in this case)
      assert final_count == initial_count,
             "Expected #{initial_count} modules after incremental changes, got #{final_count}"
    end

    test "incremental introspection skips when app not found in graph", %{test: test} do
      import ExUnit.CaptureLog

      server =
        start_supervised!(
          {Server,
           name: Module.concat(__MODULE__, test),
           introspectors: [Clarity.Introspector.Application, Clarity.Introspector.Module]}
        )

      _worker = start_supervised!({Worker, clarity_server: server})

      # Wait for initial introspection to complete
      initial_state = Clarity.get(server, :complete)
      assert initial_state.status == :done
      initial_vertex_count = initial_state.queue_info.total_vertices

      # Try incremental introspection for an app that doesn't exist
      modules_diff = %{
        changed: [String],
        added: [Enum],
        removed: []
      }

      # Capture warning log
      log =
        capture_log(fn ->
          assert :ok = Clarity.introspect(server, {:incremental, :nonexistent_app, modules_diff})

          # Should complete immediately since app not found
          final_state = Clarity.get(server, :partial)
          assert final_state.status == :done
        end)

      # Should log warning about missing app
      assert log =~ "Application nonexistent_app not found in graph"

      # Graph should be unchanged
      final_state = Clarity.get(server, :partial)
      assert final_state.queue_info.total_vertices == initial_vertex_count
    end

    @spec get_module_names_from_vertices([Clarity.Vertex.t()]) :: [module()]
    defp get_module_names_from_vertices(vertices) do
      vertices
      |> Enum.filter(&match?(%ModuleVertex{}, &1))
      |> Enum.map(fn %ModuleVertex{module: m} -> m end)
    end
  end

  describe "Event broadcasting and subscriptions" do
    test "broadcasts work_started event on introspection start", %{test: test} do
      server = start_supervised!({Server, name: Module.concat(__MODULE__, test)})

      # Subscribe to events
      unsubscribe = Clarity.subscribe(server)

      # Clear any initial events
      receive do
        {:clarity, _} -> :ok
      after
        100 -> :ok
      end

      # Trigger full introspection
      Clarity.introspect(server, :full)

      # Should receive work_started event
      assert_receive {:clarity, :work_started}

      unsubscribe.()
    end

    test "broadcasts queue_info events during task processing", %{test: test} do
      server = start_supervised!({Server, name: Module.concat(__MODULE__, test)})

      unsubscribe = Clarity.subscribe(server)

      # Clear initial events
      receive do
        {:clarity, _} -> :ok
      after
        100 -> :ok
      end

      # Pull and ack a task
      assert {:ok, task} = Server.pull_task(server)
      assert :ok = Server.ack_task(server, task.id, [])

      # Should receive queue_info event
      assert_receive {:clarity, {:work_progress, info}}
      assert is_map(info)
      assert Map.has_key?(info, :future_queue)
      assert Map.has_key?(info, :in_progress)
      assert Map.has_key?(info, :total_vertices)

      unsubscribe.()
    end

    test "broadcasts work_completed when all work is done", %{test: test} do
      server = start_supervised!({Server, name: Module.concat(__MODULE__, test)})

      unsubscribe = Clarity.subscribe(server)

      # Clear initial events
      receive do
        {:clarity, _} -> :ok
      after
        100 -> :ok
      end

      # Pull and ack all tasks
      tasks = pull_all_tasks(server)

      Enum.each(tasks, fn task ->
        Server.ack_task(server, task.id, [])
      end)

      # Should eventually receive work_completed
      assert_receive {:clarity, :work_completed}, 1000

      unsubscribe.()
    end

    test "manages subscriptions and process monitoring", %{test: test} do
      server = start_supervised!({Server, name: Module.concat(__MODULE__, test)})

      # Subscribe from a spawned process
      test_pid = self()

      subscriber_pid =
        spawn(fn ->
          unsubscribe = Clarity.subscribe(server)
          send(test_pid, {:subscribed, unsubscribe})

          receive do
            :stop -> unsubscribe.()
          end
        end)

      assert_receive {:subscribed, _unsubscribe}

      # Send an event and verify subscriber receives it
      Clarity.introspect(server, :full)

      # Subscriber should receive the event (we can't directly assert in spawned process)
      # Instead, test unsubscribe works
      send(subscriber_pid, :stop)

      # Brief wait for unsubscribe to process
      :timer.sleep(10)

      # Future events should not be received by that subscriber
      # This is hard to test directly, but we can verify the process is being monitored
      Process.exit(subscriber_pid, :kill)
      :timer.sleep(10)

      # Server should clean up the dead subscriber automatically
      # We can't easily verify this without accessing internal state
    end
  end

  # Helper functions
  @spec pull_all_tasks(GenServer.server(), [Server.Task.t()]) :: [Server.Task.t()]
  defp pull_all_tasks(server, acc \\ []) do
    case Server.pull_task(server) do
      {:ok, task} -> pull_all_tasks(server, [task | acc])
      :empty -> Enum.reverse(acc)
    end
  end

  @spec find_task_for_introspector(GenServer.server(), module()) :: {:ok, Server.Task.t()} | :empty
  defp find_task_for_introspector(server, introspector) do
    case Server.pull_task(server) do
      {:ok, task} ->
        if task.introspector == introspector do
          {:ok, task}
        else
          # Put task back by nacking it and try again
          Server.nack_task(server, task.id, :not_needed)
          find_task_for_introspector(server, introspector)
        end

      :empty ->
        :empty
    end
  end

  @spec find_task_for_vertex(GenServer.server(), Clarity.Vertex.t(), non_neg_integer()) ::
          Server.Task.t() | :not_found
  defp find_task_for_vertex(server, vertex, attempts \\ 20) do
    case {attempts, Server.pull_task(server)} do
      {0, _} ->
        :not_found

      {_, :empty} ->
        :not_found

      {_, {:ok, task}} when task.vertex == vertex ->
        task

      {n, {:ok, task}} ->
        Server.nack_task(server, task.id, :not_needed)
        find_task_for_vertex(server, vertex, n - 1)
    end
  end
end
