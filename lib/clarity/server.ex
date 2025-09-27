defmodule Clarity.Server do
  @moduledoc false

  use GenServer

  alias Clarity.Vertex.Root

  require Logger

  defmodule State do
    @moduledoc false

    defstruct [
      :future_queue,
      :in_progress,
      :graph,
      :introspectors,
      :custom_introspectors,
      :subscribers
    ]

    @type t() :: %__MODULE__{
            future_queue: :queue.queue(Clarity.Server.Task.t()),
            in_progress: %{reference() => {Clarity.Server.Task.t(), pid(), integer()}},
            graph: Clarity.Graph.t(),
            introspectors: [module()],
            custom_introspectors: [module()] | nil,
            subscribers: %{reference() => {pid(), reference()}}
          }
  end

  @doc false
  @spec start_link(opts :: GenServer.options()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {introspectors, gen_server_opts} = Keyword.pop(opts, :introspectors)
    init_opts = if introspectors, do: [introspectors: introspectors], else: []
    gen_server_opts = Keyword.put_new(gen_server_opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, init_opts, gen_server_opts)
  end

  @doc """
  Pull a task from the work queue (used by workers).
  """
  @spec pull_task(GenServer.server(), pid()) :: {:ok, Clarity.Server.Task.t()} | :empty
  def pull_task(server, worker_pid) do
    GenServer.call(server, {:pull_task, worker_pid})
  end

  @doc """
  Acknowledge task completion (used by workers).
  """
  @spec ack_task(GenServer.server(), reference(), Clarity.Introspector.results(), pid()) :: :ok
  def ack_task(server, task_id, result, worker_pid) do
    GenServer.call(server, {:ack_task, task_id, result, worker_pid}, 30_000)
  end

  @doc """
  Report task failure (used by workers).
  """
  @spec nack_task(GenServer.server(), reference(), term(), pid()) :: :ok
  def nack_task(server, task_id, error, worker_pid) do
    GenServer.call(server, {:nack_task, task_id, error, worker_pid})
  end

  @impl GenServer
  def init(opts) do
    # Create new graph
    graph = Clarity.Graph.new()

    # Get introspectors from options or use defaults
    custom_introspectors = Keyword.get(opts, :introspectors)

    # Create initial state with empty graph
    initial_state = %State{
      future_queue: :queue.new(),
      in_progress: %{},
      graph: graph,
      introspectors: [],
      custom_introspectors: custom_introspectors,
      subscribers: %{}
    }

    {future_queue, introspectors} =
      reset_queue_and_introspectors(initial_state.graph, custom_introspectors)

    state = %{
      initial_state
      | future_queue: future_queue,
        introspectors: introspectors
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:unsubscribe, subscription_ref}, state) do
    case Map.pop(state.subscribers, subscription_ref) do
      {{_pid, monitor_ref}, new_subscribers} ->
        Process.demonitor(monitor_ref, [:flush])
        {:noreply, %{state | subscribers: new_subscribers}}

      {nil, _} ->
        {:noreply, state}
    end
  end

  def handle_cast({:introspect, :full}, state) do
    :ok = Clarity.Graph.clear(state.graph)

    {future_queue, introspectors} =
      reset_queue_and_introspectors(state.graph, state.custom_introspectors)

    new_state = %{
      state
      | future_queue: future_queue,
        introspectors: introspectors
    }

    broadcast_event(new_state, :work_started)
    broadcast_event(new_state, {:work_progress, queue_info(new_state)})

    {:noreply, new_state}
  end

  def handle_cast({:introspect, {:incremental, app, modules_diff}}, state) do
    if contains_introspector_modules?(modules_diff, state.introspectors) do
      Logger.info("Introspector modules changed, falling back to full introspection")
      # Fall back to full introspection - introspector logic may have changed
      handle_cast({:introspect, :full}, state)
    else
      Logger.info(
        "Performing incremental introspection for app #{app}: #{length(modules_diff.changed)} changed, #{length(modules_diff.added)} added, #{length(modules_diff.removed)} removed modules"
      )

      # Find the Application vertex for this app
      app_vertex = find_application_vertex(state.graph, app)

      if app_vertex do
        # Process incrementally
        modules_to_purge = modules_diff.changed ++ modules_diff.removed
        modules_to_add = modules_diff.changed ++ modules_diff.added

        # 1. Find and purge vertices for changed + removed modules
        module_vertices = find_module_vertices(state.graph, modules_to_purge)
        Enum.each(module_vertices, &Clarity.Graph.purge(state.graph, &1))

        # 2. Create new vertices and edges for changed + added modules
        introspection_results =
          Clarity.Introspector.Module.introspect_modules(
            app_vertex,
            modules_to_add,
            state.graph
          )

        # 3. Process the results directly by creating a task
        task = %Clarity.Server.Task{
          id: make_ref(),
          vertex: app_vertex,
          introspector: Clarity.Introspector.Module,
          graph: Clarity.Graph.seal(state.graph),
          created_at: System.monotonic_time(:millisecond)
        }

        broadcast_event(state, :work_started)
        state = process_task_results(task, introspection_results, state)

        {:noreply, state}
      else
        Logger.warning(
          "Application #{app} not found in graph, skipping incremental introspection"
        )

        {:noreply, state}
      end
    end
  end

  @impl GenServer
  def handle_call(:subscribe, {pid, _ref}, state) do
    subscription_ref = make_ref()
    monitor_ref = Process.monitor(pid)

    server = self()

    unsubscribe = fn ->
      GenServer.cast(server, {:unsubscribe, subscription_ref})
    end

    new_subscribers = Map.put(state.subscribers, subscription_ref, {pid, monitor_ref})
    {:reply, unsubscribe, %{state | subscribers: new_subscribers}}
  end

  def handle_call(:get, _from, state) do
    status = if queue_empty_and_no_progress?(state), do: :done, else: :working

    clarity = %Clarity{
      graph: Clarity.Graph.seal(state.graph),
      status: status,
      queue_info: queue_info(state)
    }

    {:reply, clarity, state}
  end

  def handle_call({:pull_task, worker_pid}, _from, state) do
    case :queue.out(state.future_queue) do
      {{:value, task}, remaining_queue} ->
        start_time = System.monotonic_time(:millisecond)
        new_in_progress = Map.put(state.in_progress, task.id, {task, worker_pid, start_time})
        new_state = %{state | future_queue: remaining_queue, in_progress: new_in_progress}
        {:reply, {:ok, task}, new_state}

      {:empty, _queue} ->
        {:reply, :empty, state}
    end
  end

  @impl GenServer
  def handle_call({:ack_task, task_id, result, worker_pid}, _from, state) do
    case Map.pop(state.in_progress, task_id) do
      {{task, ^worker_pid, _start_time}, remaining_in_progress} ->
        new_state =
          process_task_results(task, result, %{state | in_progress: remaining_in_progress})

        {:reply, :ok, new_state}

      {{_task, _other_worker, _start_time}, _} ->
        # Task exists but different worker - ignore
        {:reply, :ok, state}

      {nil, _} ->
        {:reply, :ok, state}
    end
  end

  @impl GenServer
  def handle_call({:nack_task, task_id, error, worker_pid}, _from, state) do
    case Map.pop(state.in_progress, task_id) do
      {{task, ^worker_pid, _start_time}, remaining_in_progress} ->
        Logger.warning(
          "Task failed: #{Clarity.Server.Task.describe(task)}, error: #{inspect(error)}"
        )

        {:reply, :ok, %{state | in_progress: remaining_in_progress}}

      {{_task, _other_worker, _start_time}, _} ->
        Logger.warning(
          "Received nack for task #{inspect(task_id)} from non-owning worker #{inspect(worker_pid)}"
        )

        {:reply, :ok, state}

      {nil, _} ->
        {:reply, :ok, state}
    end
  end

  @impl GenServer
  def handle_info({:DOWN, monitor_ref, :process, _pid, _reason}, state) do
    # Remove subscription when subscriber process dies
    new_subscribers =
      state.subscribers
      |> Enum.reject(fn {_ref, {_pid, mon_ref}} -> mon_ref == monitor_ref end)
      |> Map.new()

    {:noreply, %{state | subscribers: new_subscribers}}
  end

  @spec create_tasks_for_vertex(Clarity.Vertex.t(), [module()], Clarity.Graph.t()) :: [
          Clarity.Server.Task.t()
        ]
  defp create_tasks_for_vertex(vertex, introspectors, graph) do
    vertex_type = vertex.__struct__

    introspectors
    |> Enum.filter(fn introspector ->
      vertex_type in introspector.source_vertex_types()
    end)
    |> Enum.map(&Clarity.Server.Task.new_introspection(vertex, &1, Clarity.Graph.seal(graph)))
  end

  @spec process_task_results(Clarity.Server.Task.t(), Clarity.Introspector.results(), State.t()) ::
          State.t()
  defp process_task_results(task, results, state) do
    # First pass: collect all vertices created by this introspection
    created_vertices =
      results
      |> Enum.filter(&match?({:vertex, _}, &1))
      |> MapSet.new(fn {:vertex, vertex} -> vertex end)

    # Add the causing vertex to allowed vertices for edge validation
    allowed_edge_vertices = MapSet.put(created_vertices, task.vertex)

    new_tasks =
      Enum.flat_map(results, fn
        {:vertex, vertex} ->
          # Add vertex using Graph with provenance tracking
          Clarity.Graph.add_vertex(state.graph, vertex, task.vertex)

          # Create tasks for this new vertex
          create_tasks_for_vertex(
            vertex,
            state.introspectors,
            state.graph
          )

        {:edge, nil, _to_vertex, _label} ->
          []

        {:edge, _from_vertex, nil, _label} ->
          []

        {:edge, from_vertex, to_vertex, label} ->
          # Validate edge provenance - either from_vertex OR to_vertex must be allowed
          if MapSet.member?(allowed_edge_vertices, from_vertex) or
               MapSet.member?(allowed_edge_vertices, to_vertex) do
            # Add edge using Graph
            Clarity.Graph.add_edge(state.graph, from_vertex, to_vertex, label)
          else
            Logger.warning(
              "Discarding invalid edge: neither from_vertex #{inspect(from_vertex)} nor to_vertex #{inspect(to_vertex)} " <>
                "were created by this introspection or are the causing vertex #{inspect(task.vertex)}. " <>
                "Introspectors should only create edges that reference the causing vertex or vertices they create."
            )
          end

          []
      end)

    # Add new tasks to the queue
    new_queue = Enum.reduce(new_tasks, state.future_queue, &:queue.in(&1, &2))

    # Tree is maintained incrementally, no rebuild needed
    state = %{state | future_queue: new_queue}

    # Broadcast work_progress for both progress updates and content changes
    # (digraph reference automatically reflects new vertices to UI)
    broadcast_event(state, {:work_progress, queue_info(state)})

    # Broadcast work_completed when all work is done
    if queue_empty_and_no_progress?(state) do
      broadcast_event(state, :work_completed)
    end

    state
  end

  @spec queue_empty_and_no_progress?(State.t()) :: boolean()
  defp queue_empty_and_no_progress?(state) do
    :queue.is_empty(state.future_queue) && map_size(state.in_progress) == 0
  end

  @spec broadcast_event(State.t(), Clarity.event()) :: :ok
  defp broadcast_event(state, event) do
    Enum.each(state.subscribers, fn {_ref, {pid, _monitor_ref}} ->
      send(pid, {:clarity, event})
    end)
  end

  @spec queue_info(State.t()) :: Clarity.queue_info()
  defp queue_info(state) do
    %{
      future_queue: :queue.len(state.future_queue),
      in_progress: map_size(state.in_progress),
      total_vertices: Clarity.Graph.vertex_count(state.graph)
    }
  end

  @spec reset_queue_and_introspectors(Clarity.Graph.t(), [module()] | nil) ::
          {:queue.queue(Clarity.Server.Task.t()), [module()]}
  defp reset_queue_and_introspectors(graph, custom_introspectors) do
    root_vertex = %Root{}

    introspectors = custom_introspectors || Clarity.Introspector.list()

    initial_tasks =
      create_tasks_for_vertex(root_vertex, introspectors, graph)

    queue = Enum.reduce(initial_tasks, :queue.new(), &:queue.in(&1, &2))
    {queue, introspectors}
  end

  @spec contains_introspector_modules?(Clarity.modules_diff(), [Clarity.Introspector.t()]) ::
          boolean()
  defp contains_introspector_modules?(modules_diff, introspectors) do
    all_changed = modules_diff.changed ++ modules_diff.added ++ modules_diff.removed
    # The introspectors list already contains module names
    introspector_modules = introspectors

    not MapSet.disjoint?(MapSet.new(all_changed), MapSet.new(introspector_modules))
  end

  @spec find_module_vertices(Clarity.Graph.t(), [module()]) :: [Clarity.Vertex.Module.t()]
  defp find_module_vertices(graph, module_names) do
    graph
    |> Clarity.Graph.vertices()
    |> Enum.filter(fn
      %Clarity.Vertex.Module{module: mod} -> mod in module_names
      _ -> false
    end)
  end

  @spec find_application_vertex(Clarity.Graph.t(), Application.app()) ::
          Clarity.Vertex.Application.t() | nil
  defp find_application_vertex(graph, app) do
    graph
    |> Clarity.Graph.vertices()
    |> Enum.find(fn
      %Clarity.Vertex.Application{app: ^app} -> true
      _ -> false
    end)
  end
end
