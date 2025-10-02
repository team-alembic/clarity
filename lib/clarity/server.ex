defmodule Clarity.Server do
  @moduledoc false

  use GenServer

  alias Clarity.Vertex.Root

  require Logger

  defmodule State do
    @moduledoc false

    @enforce_keys [:graph, :introspectors, :name]
    defstruct [
      :graph,
      :introspectors,
      :name,
      future_queue: :queue.new(),
      requeue_queue: :queue.new(),
      in_progress: %{},
      custom_introspectors: nil
    ]

    @type t() :: %__MODULE__{
            future_queue: :queue.queue(Clarity.Server.Task.t()),
            requeue_queue: :queue.queue(Clarity.Server.Task.t()),
            in_progress: %{reference() => Clarity.Server.Task.t()},
            graph: Clarity.Graph.t(),
            introspectors: [module()],
            custom_introspectors: [module()] | nil,
            name: GenServer.name()
          }
  end

  @doc false
  @spec start_link(opts :: GenServer.options()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {introspectors, gen_server_opts} = Keyword.pop(opts, :introspectors)
    init_opts = if introspectors, do: [introspectors: introspectors], else: []
    gen_server_opts = Keyword.put_new(gen_server_opts, :name, __MODULE__)

    GenServer.start_link(__MODULE__, init_opts ++ gen_server_opts, gen_server_opts)
  end

  @doc """
  Pull a task from the work queue (used by workers).
  """
  @spec pull_task(GenServer.server()) :: {:ok, Clarity.Server.Task.t()} | :empty
  def pull_task(server) do
    GenServer.call(server, :pull_task)
  end

  @doc """
  Acknowledge task completion (used by workers).
  """
  @spec ack_task(GenServer.server(), reference(), [Clarity.Introspector.entry()]) :: :ok
  def ack_task(server, task_id, result) do
    GenServer.cast(server, {:ack_task, task_id, result})
  end

  @doc """
  Report task failure (used by workers).
  """
  @spec nack_task(GenServer.server(), reference(), term()) :: :ok
  def nack_task(server, task_id, error) do
    GenServer.cast(server, {:nack_task, task_id, error})
  end

  @doc """
  Re-queue a task due to unmet dependencies. Task will be pushed to the back of
  the queue.
  """
  @spec requeue_task(GenServer.server(), reference()) :: :ok
  def requeue_task(server, task_id) do
    GenServer.cast(server, {:requeue_task, task_id})
  end

  @impl GenServer
  def init(opts) do
    # Create new graph
    graph = Clarity.Graph.new()

    # Get introspectors from options or use defaults
    custom_introspectors = Keyword.get(opts, :introspectors)

    # Create initial state with empty graph
    initial_state = %State{
      graph: graph,
      custom_introspectors: custom_introspectors,
      introspectors: custom_introspectors || [],
      name: Keyword.fetch!(opts, :name)
    }

    {future_queue, introspectors} =
      reset_queue_and_introspectors(initial_state.graph, custom_introspectors)

    state = %{
      initial_state
      | future_queue: future_queue,
        introspectors: introspectors
    }

    broadcast_event(state, :work_started)

    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:introspect, :full}, state) do
    :ok = Clarity.Graph.clear(state.graph)

    {future_queue, introspectors} =
      reset_queue_and_introspectors(state.graph, state.custom_introspectors)

    state = %{
      state
      | future_queue: future_queue,
        introspectors: introspectors
    }

    {:noreply, state}
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
          graph: state.graph
        }

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

  def handle_cast({:ack_task, task_id, result}, state) do
    case Map.pop(state.in_progress, task_id) do
      {nil, _} ->
        Logger.warning(
          "Received nack for unknown task #{inspect(task_id)}. The task may have already been acknowledged or requeued."
        )

        {:noreply, state}

      {task, remaining_in_progress} ->
        new_state =
          process_task_results(task, result, %{state | in_progress: remaining_in_progress})

        {:noreply, new_state}
    end
  end

  def handle_cast({:nack_task, task_id, error}, state) do
    case Map.pop(state.in_progress, task_id) do
      {nil, _} ->
        Logger.warning(
          "Received ack for unknown task #{inspect(task_id)}. The task may have already been acknowledged or requeued."
        )

        {:noreply, state}

      {task, remaining_in_progress} ->
        Logger.warning(
          "Task failed: #{Clarity.Server.Task.describe(task)}, error: #{inspect(error)}"
        )

        {:noreply, %{state | in_progress: remaining_in_progress}}
    end
  end

  def handle_cast({:requeue_task, task_id}, state) do
    case Map.pop(state.in_progress, task_id) do
      {nil, _} ->
        Logger.warning(
          "Received requeue for unknown task #{inspect(task_id)}. The task may have already been acknowledged or requeued."
        )

        {:noreply, state}

      {%{requeue_count: count} = task, remaining_in_progress} when count >= 100 ->
        Logger.warning(
          "Dropping task after #{count + 1} requeue attempts: #{Clarity.Server.Task.describe(task)}"
        )

        {:noreply, %{state | in_progress: remaining_in_progress}}

      {task, remaining_in_progress} ->
        task = %{task | requeue_count: task.requeue_count + 1}

        {:noreply,
         %{
           state
           | in_progress: remaining_in_progress,
             requeue_queue: :queue.in(task, state.requeue_queue)
         }}
    end
  end

  @impl GenServer
  def handle_call(:get, _from, state) do
    status = if queue_empty_and_no_progress?(state), do: :done, else: :working

    clarity = %Clarity{
      graph: state.graph,
      status: status,
      queue_info: queue_info(state)
    }

    {:reply, clarity, state}
  end

  def handle_call(:pull_task, from, state) do
    case :queue.out(state.future_queue) do
      {{:value, task}, remaining_queue} ->
        new_in_progress = Map.put(state.in_progress, task.id, task)
        new_state = %{state | future_queue: remaining_queue, in_progress: new_in_progress}
        {:reply, {:ok, task}, new_state}

      {:empty, _queue} ->
        cond do
          # Still have in-progress tasks - wait for them to complete
          # If we didn't do this, we could end up in a busy loop
          # if all tasks kept failing with unmet dependencies
          # while a longer running task is still in progress producing those
          # dependencies
          state.in_progress != %{} ->
            {:reply, :empty, state}

          # No in-progress tasks and have requeued tasks - swap queues
          not :queue.is_empty(state.requeue_queue) ->
            state = %{state | future_queue: state.requeue_queue, requeue_queue: :queue.new()}

            broadcast_event(state, :__restart_pulling__)

            handle_call(:pull_task, from, state)

          true ->
            {:reply, :empty, state}
        end
    end
  end

  defoverridable handle_cast: 2, handle_call: 3

  @impl GenServer
  def handle_cast(msg, state) do
    {:noreply, new_state} = super(msg, state)

    handle_state_change(state, new_state)

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_call(msg, from, state) do
    {:reply, reply, new_state} = super(msg, from, state)
    handle_state_change(state, new_state)
    {:reply, reply, new_state}
  end

  @spec handle_state_change(old :: State.t(), new :: State.t()) :: :ok
  def handle_state_change(old, new)
  def handle_state_change(state, state), do: :ok

  def handle_state_change(old, new) do
    cond do
      queue_empty_and_no_progress?(old) and not queue_empty_and_no_progress?(new) ->
        broadcast_event(new, :work_started)
        broadcast_event(new, {:work_progress, queue_info(new)})

      not queue_empty_and_no_progress?(old) and queue_empty_and_no_progress?(new) ->
        broadcast_event(new, :work_completed)

      true ->
        broadcast_event(new, {:work_progress, queue_info(new)})
    end
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
    |> Enum.map(&Clarity.Server.Task.new_introspection(vertex, &1, graph))
  end

  @spec process_task_results(Clarity.Server.Task.t(), [Clarity.Introspector.entry()], State.t()) ::
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

    state
  end

  @spec queue_empty_and_no_progress?(State.t()) :: boolean()
  defp queue_empty_and_no_progress?(state) do
    :queue.is_empty(state.future_queue) && :queue.is_empty(state.requeue_queue) &&
      map_size(state.in_progress) == 0
  end

  @spec broadcast_event(State.t(), Clarity.event()) :: :ok
  defp broadcast_event(state, event) do
    topic =
      case event do
        topic when is_atom(topic) -> topic
        tuple when is_tuple(tuple) -> elem(tuple, 0)
      end

    for name <- [state.name, self()] do
      Registry.dispatch(Clarity.PubSub, {name, topic}, fn entries ->
        for {pid, ref} <- entries do
          case ref do
            nil -> send(pid, {:clarity, event})
            _ -> send(pid, {:clarity, ref, event})
          end
        end
      end)
    end

    :ok
  end

  @spec queue_info(State.t()) :: Clarity.queue_info()
  defp queue_info(state) do
    %{
      future_queue: :queue.len(state.future_queue),
      requeue_queue: :queue.len(state.requeue_queue),
      in_progress: map_size(state.in_progress),
      total_vertices: Clarity.Graph.vertex_count(state.graph)
    }
  end

  @spec reset_queue_and_introspectors(Clarity.Graph.t(), [module()] | nil) ::
          {:queue.queue(Clarity.Server.Task.t()), [module()]}
  defp reset_queue_and_introspectors(graph, custom_introspectors) do
    root_vertex = %Root{}

    introspectors = custom_introspectors || Clarity.Config.list_introspectors()

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
