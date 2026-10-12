defmodule Clarity.Server do
  @moduledoc false

  use GenServer

  alias Clarity.Config
  alias Clarity.Graph
  alias Clarity.Graph.Cache
  alias Clarity.Server.Queue
  alias Clarity.Vertex
  alias Clarity.Vertex.Root
  alias Clarity.Vertex.Util

  require Logger

  defmodule State do
    @moduledoc false

    @enforce_keys [:graph, :introspectors, :name]
    defstruct [
      :graph,
      :introspectors,
      :name,
      :cache,
      :retried_ms,
      :queue,
      waiting: [],
      waiting_count: 0,
      in_progress: %{},
      custom_introspectors: nil,
      started?: false,
      project_apps: :all,
      wanted: %{},
      promoted: MapSet.new(),
      prioritized_apps: MapSet.new()
    ]

    # - `queue`: the tasks to run, in lanes (see Clarity.Server.Queue)
    # - `waiting`: the tasks that ran before what they need was in the graph,
    #   to run again (see maybe_retry_waiting/1)
    # - `project_apps`: the applications of the project, introspected first
    # - `wanted`: modules of the dependencies some task needs, and the lane
    #   to introspect them in
    # - `promoted`: the modules already pulled forward, by lane
    # - `prioritized_apps`: dependencies someone is looking at, introspected
    #   with the project's
    @type t() :: %__MODULE__{
            queue: Queue.t(),
            waiting: [Clarity.Server.Task.t()],
            waiting_count: non_neg_integer(),
            retried_ms: integer() | nil,
            in_progress: %{reference() => Clarity.Server.Task.t()},
            graph: Graph.t(),
            introspectors: [module()],
            custom_introspectors: [module()] | nil,
            name: GenServer.name(),
            cache: GenServer.server() | nil,
            started?: boolean(),
            project_apps: MapSet.t(Application.app()) | :all,
            wanted: %{module() => Queue.lane()},
            promoted: MapSet.t({module(), Queue.lane()}),
            prioritized_apps: MapSet.t(Application.app())
          }
  end

  # How often, at most, tasks waiting on something run again while the
  # dependencies are being introspected.
  @retry_interval 500

  @doc false
  @spec start_link(opts :: GenServer.options()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {init_opts, gen_server_opts} = Keyword.split(opts, [:introspectors, :cache])

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
  Re-queue a task due to unmet dependencies, to run again once the graph has
  more in it. `needs` are the modules whose introspection it waits for, which
  are introspected sooner for it.
  """
  @spec requeue_task(GenServer.server(), reference(), [module()]) :: :ok
  def requeue_task(server, task_id, needs \\ []) do
    GenServer.cast(server, {:requeue_task, task_id, needs})
  end

  @doc """
  Introspects the application of `vertex` (an application or module vertex)
  with the project's, if it's a dependency still to come: someone is looking
  at it.
  """
  @spec prioritize(GenServer.server(), Vertex.t()) :: :ok
  def prioritize(server, vertex) do
    GenServer.cast(server, {:prioritize, vertex})
  end

  @impl GenServer
  def init(opts) do
    custom_introspectors = Keyword.get(opts, :introspectors)
    name = Keyword.fetch!(opts, :name)
    cache = Keyword.get(opts, :cache)
    auto_start? = Keyword.get(opts, :auto_start?, true)

    state = %State{
      graph: Graph.new(),
      custom_introspectors: custom_introspectors,
      introspectors: custom_introspectors || [],
      name: name,
      cache: cache,
      queue: Queue.new(),
      started?: false
    }

    if auto_start? do
      {:ok, state, {:continue, :auto_start}}
    else
      {:ok, state}
    end
  end

  @impl GenServer
  def handle_continue(:auto_start, state) do
    {:noreply, ensure_started(state)}
  end

  @impl GenServer
  def handle_cast({:introspect, :full}, state) do
    :ok = Config.forget_module_applications()
    state = ensure_started(state)

    :ok = Graph.clear(state.graph)

    {:noreply, reset(state)}
  end

  def handle_cast(
        {:introspect, {:incremental, _app, _modules_diff}},
        %State{started?: false} = state
      ) do
    {:noreply, state}
  end

  def handle_cast({:introspect, {:incremental, app, modules_diff}}, state) do
    :ok = Config.forget_module_applications()

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
        Enum.each(module_vertices, &Graph.purge(state.graph, &1))

        # 2. Create new vertices and edges for changed + added modules
        introspection_results =
          Clarity.Introspector.Module.introspect_modules(
            app_vertex,
            modules_to_add,
            state.graph
          )

        # 3. Process the results directly by creating a task
        task =
          Clarity.Server.Task.new_introspection(
            app_vertex,
            Clarity.Introspector.Module,
            state.graph
          )

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

  def handle_cast({:prioritize, vertex}, state) do
    app =
      case vertex do
        %Vertex.Application{app: app} -> app
        %Vertex.Module{module: module} -> Config.application_of(module)
        _vertex -> nil
      end

    if app == nil or project_app?(state, app) or MapSet.member?(state.prioritized_apps, app) do
      {:noreply, state}
    else
      queue =
        Queue.promote(state.queue, :model, fn
          %{vertex: %Vertex.Application{app: ^app}} -> true
          %{vertex: %Vertex.Module{module: module}} -> Config.application_of(module) == app
          _task -> false
        end)

      {:noreply,
       %{state | queue: queue, prioritized_apps: MapSet.put(state.prioritized_apps, app)}}
    end
  end

  def handle_cast({:ack_task, task_id, result}, state) do
    case Map.pop(state.in_progress, task_id) do
      {nil, _} ->
        Logger.warning(
          "Received ack for unknown task #{inspect(task_id)}. The task may have already been acknowledged or requeued."
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
          "Received nack for unknown task #{inspect(task_id)}. The task may have already been acknowledged or requeued."
        )

        {:noreply, state}

      {task, remaining_in_progress} ->
        Logger.warning(
          "Task failed: #{Clarity.Server.Task.describe(task)}, error: #{inspect(error)}"
        )

        {:noreply, %{state | in_progress: remaining_in_progress}}
    end
  end

  def handle_cast({:requeue_task, task_id, needs}, state) do
    case Map.pop(state.in_progress, task_id) do
      {nil, _} ->
        Logger.warning(
          "Received requeue for unknown task #{inspect(task_id)}. The task may have already been acknowledged or requeued."
        )

        {:noreply, state}

      {task, remaining_in_progress} ->
        task = %{task | requeue_count: task.requeue_count + 1}

        state = %{
          state
          | in_progress: remaining_in_progress,
            waiting: [task | state.waiting],
            waiting_count: state.waiting_count + 1
        }

        {:noreply, promote_needs(state, needs, task.lane)}
    end
  end

  @impl GenServer
  def handle_call(:get, _from, state) do
    state = ensure_started(state)

    status = if queue_empty_and_no_progress?(state), do: :done, else: :working

    clarity = %Clarity{
      graph: state.graph,
      status: status,
      queue_info: queue_info(state)
    }

    {:reply, clarity, state}
  end

  def handle_call(:pull_task, _from, state) do
    state = maybe_retry_waiting(state)

    case Queue.pop(state.queue) do
      {:ok, task, queue} ->
        task = %{task | ran_at: Graph.get_update_count(state.graph)}
        new_in_progress = Map.put(state.in_progress, task.id, task)
        {:reply, {:ok, task}, %{state | queue: queue, in_progress: new_in_progress}}

      :empty ->
        {:reply, :empty, maybe_drop_waiting(state)}
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

  @spec create_tasks_for_vertex(Vertex.t(), Queue.lane(), State.t()) :: [
          Clarity.Server.Task.t()
        ]
  defp create_tasks_for_vertex(vertex, parent_lane, state) do
    vertex_type = vertex.__struct__

    state.introspectors
    |> Enum.filter(fn introspector ->
      vertex_type in introspector.source_vertex_types()
    end)
    |> Enum.map(
      &Clarity.Server.Task.new_introspection(
        vertex,
        &1,
        state.graph,
        lane(vertex, &1, parent_lane, state)
      )
    )
  end

  # The lane a task runs in (see Clarity.Server.Queue). The project's
  # applications and modules come first: what the modules define, then how
  # they relate. The dependencies' come last, unless a task needs one of their
  # modules sooner. Every other vertex is found introspecting one of those, so
  # is introspected in the same lane.
  @spec lane(Vertex.t(), module(), Queue.lane(), State.t()) :: Queue.lane()
  defp lane(%Vertex.Application{app: app}, _introspector, _parent_lane, state),
    do: if(project_app?(state, app) or prioritized?(state, app), do: :model, else: :dependencies)

  defp lane(%Vertex.Module{module: module}, introspector, _parent_lane, state) do
    app = Config.application_of(module)
    project? = project_app?(state, app)

    cond do
      prioritized?(state, app) -> :model
      introspector == Clarity.Introspector.Module and project? -> :modules
      introspector == Clarity.Introspector.Module -> :dependencies
      project? -> :model
      true -> Map.get(state.wanted, module, :dependencies)
    end
  end

  defp lane(_vertex, _introspector, parent_lane, _state), do: parent_lane

  @spec prioritized?(State.t(), Application.app() | nil) :: boolean()
  defp prioritized?(state, app), do: MapSet.member?(state.prioritized_apps, app)

  @spec project_app?(State.t(), Application.app() | nil) :: boolean()
  defp project_app?(%State{project_apps: :all}, _app), do: true
  defp project_app?(%State{project_apps: apps}, app), do: MapSet.member?(apps, app)

  # Pulls the modules a waiting task needs forward, into its lane: the tasks
  # finding what each module defines, and listing its application's modules,
  # if that's still to come.
  @spec promote_needs(State.t(), [module()], Queue.lane()) :: State.t()
  defp promote_needs(state, modules, lane) do
    Enum.reduce(modules, state, fn module, state ->
      if MapSet.member?(state.promoted, {module, lane}) do
        state
      else
        promote_module(
          %{state | promoted: MapSet.put(state.promoted, {module, lane})},
          module,
          lane
        )
      end
    end)
  end

  # The project's modules are introspected first anyway, so only the
  # dependencies' are brought forward.
  @spec promote_module(State.t(), module(), Queue.lane()) :: State.t()
  defp promote_module(state, module, lane) do
    app = Config.application_of(module)

    if app == nil or project_app?(state, app) do
      state
    else
      queue =
        Queue.promote(state.queue, lane, fn
          %{vertex: %Vertex.Application{app: ^app}} ->
            true

          %{vertex: %Vertex.Module{module: ^module}, introspector: introspector} ->
            introspector != Clarity.Introspector.Module

          _task ->
            false
        end)

      %{
        state
        | queue: queue,
          wanted: Map.update(state.wanted, module, lane, &Queue.earlier(&1, lane))
      }
    end
  end

  # Waiting tasks run again once nothing they could need from the project is
  # still to come, if the graph has changed since they last started: each
  # against its own start, as a task that ran while others were retried may
  # have missed what arrived meanwhile. While the dependencies are
  # introspected, which they may need too, that's at most every
  # @retry_interval ms.
  @spec maybe_retry_waiting(State.t()) :: State.t()
  defp maybe_retry_waiting(%State{waiting: []} = state), do: state

  defp maybe_retry_waiting(state) do
    update_count = Graph.get_update_count(state.graph)
    now = System.monotonic_time(:millisecond)

    project_busy? =
      Queue.size(state.queue, [:model, :modules]) > 0 or
        Enum.any?(state.in_progress, fn {_id, task} -> task.lane != :dependencies end)

    idle? = Queue.size(state.queue) == 0 and state.in_progress == %{}
    due? = idle? or state.retried_ms == nil or now - state.retried_ms >= @retry_interval

    with true <- not project_busy? and due?,
         {[_ | _] = changed, unchanged} <-
           Enum.split_with(state.waiting, &(&1.ran_at != update_count)) do
      queue = changed |> Enum.reverse() |> Enum.reduce(state.queue, &Queue.push(&2, &1))
      broadcast_event(state, :__restart_pulling__)

      %{
        state
        | queue: queue,
          waiting: unchanged,
          waiting_count: length(unchanged),
          retried_ms: now
      }
    else
      _wait -> state
    end
  end

  # Once nothing is left to run, and the graph hasn't changed since any of the
  # waiting tasks last started, what they wait for will never come.
  @spec maybe_drop_waiting(State.t()) :: State.t()
  defp maybe_drop_waiting(%State{waiting: []} = state), do: state

  defp maybe_drop_waiting(state) do
    update_count = Graph.get_update_count(state.graph)

    if state.in_progress == %{} and Enum.all?(state.waiting, &(&1.ran_at == update_count)) do
      for task <- state.waiting do
        Logger.warning(
          "Dropping task after #{attempts(task.requeue_count)}, as what it needs never came: " <>
            Clarity.Server.Task.describe(task)
        )
      end

      %{state | waiting: [], waiting_count: 0}
    else
      state
    end
  end

  @spec attempts(pos_integer()) :: String.t()
  defp attempts(1), do: "1 attempt"
  defp attempts(count), do: "#{count} attempts"

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
          Graph.add_vertex(state.graph, vertex, task.vertex)

          # Create tasks for this new vertex
          create_tasks_for_vertex(vertex, task.lane, state)

        {:edge, nil, _to_vertex, _label} ->
          []

        {:edge, _from_vertex, nil, _label} ->
          []

        {:edge, from_vertex, to_vertex, label} ->
          # Validate edge provenance - either from_vertex OR to_vertex must be allowed
          if MapSet.member?(allowed_edge_vertices, from_vertex) or
               MapSet.member?(allowed_edge_vertices, to_vertex) do
            # Add edge using Graph
            Graph.add_edge(state.graph, from_vertex, to_vertex, label)
          else
            Logger.warning(
              "Discarding invalid edge: neither from_vertex #{inspect(from_vertex)} nor to_vertex #{inspect(to_vertex)} " <>
                "were created by this introspection or are the causing vertex #{inspect(task.vertex)}. " <>
                "Introspectors should only create edges that reference the causing vertex or vertices they create."
            )
          end

          []

        {:purge, vertex} ->
          if task.introspector in [
               Clarity.Introspector.Application,
               Clarity.Introspector.Module
             ] do
            Graph.purge(state.graph, vertex)
          else
            Logger.error(
              "Introspector #{inspect(task.introspector)} attempted to emit a purge entry. " <>
                "Only Clarity.Introspector.Application and Clarity.Introspector.Module may emit purge entries."
            )
          end

          []
      end)

    # Tree is maintained incrementally, no rebuild needed
    %{state | queue: Enum.reduce(new_tasks, state.queue, &Queue.push(&2, &1))}
  end

  @spec queue_empty_and_no_progress?(State.t()) :: boolean()
  defp queue_empty_and_no_progress?(state) do
    Queue.size(state.queue) == 0 and state.waiting == [] and map_size(state.in_progress) == 0
  end

  @spec broadcast_event(State.t(), Clarity.event()) :: :ok
  defp broadcast_event(state, event) do
    topic = event_topic(event)

    for name <- [state.name, self()] do
      Registry.dispatch(Clarity.PubSub, {name, topic}, &dispatch_event(&1, event))
    end

    :ok
  end

  @spec event_topic(Clarity.event()) :: atom()
  defp event_topic(event) when is_atom(event), do: event
  defp event_topic(event) when is_tuple(event), do: elem(event, 0)

  @spec dispatch_event([{pid(), term()}], Clarity.event()) :: :ok
  defp dispatch_event(entries, event) do
    Enum.each(entries, fn {pid, ref} -> send_event(pid, ref, event) end)
  end

  @spec send_event(pid(), reference() | nil, Clarity.event()) :: term()
  defp send_event(pid, nil, event), do: send(pid, {:clarity, event})
  defp send_event(pid, ref, event), do: send(pid, {:clarity, ref, event})

  @spec queue_info(State.t()) :: Clarity.queue_info()
  defp queue_info(state) do
    %{
      future_queue: Queue.size(state.queue),
      requeue_queue: state.waiting_count,
      in_progress: map_size(state.in_progress),
      total_vertices: Graph.vertex_count(state.graph)
    }
  end

  @spec load_graph_or_fallback(GenServer.server() | nil, Graph.t()) :: Graph.t()
  defp load_graph_or_fallback(nil, fallback_graph), do: fallback_graph

  defp load_graph_or_fallback(cache, fallback_graph) do
    case Cache.load(cache) do
      {:ok, cached_graph} ->
        Logger.info("Loaded graph from cache")
        cached_graph

      {:error, reason} ->
        Logger.debug("Cache not available (#{inspect(reason)}), using empty graph")
        fallback_graph
    end
  end

  # Starts introspection over from the root.
  @spec reset(State.t()) :: State.t()
  defp reset(state) do
    state = %{
      state
      | introspectors: state.custom_introspectors || Config.list_introspectors(),
        project_apps: Config.project_applications(),
        waiting: [],
        waiting_count: 0,
        retried_ms: nil,
        wanted: %{},
        promoted: MapSet.new(),
        prioritized_apps: MapSet.new()
    }

    tasks = create_tasks_for_vertex(%Root{}, :model, state)
    %{state | queue: Enum.reduce(tasks, Queue.new(), &Queue.push(&2, &1))}
  end

  @spec ensure_started(State.t()) :: State.t()
  defp ensure_started(%State{started?: true} = state), do: state

  defp ensure_started(%State{started?: false} = state) do
    # Load cache if configured, fallback to existing graph
    graph = load_graph_or_fallback(state.cache, state.graph)

    new_state = reset(%{state | graph: graph, started?: true})

    broadcast_event(new_state, :work_started)

    new_state
  end

  @spec contains_introspector_modules?(Clarity.modules_diff(), [Clarity.Introspector.t()]) ::
          boolean()
  defp contains_introspector_modules?(modules_diff, introspectors) do
    all_changed = modules_diff.changed ++ modules_diff.added ++ modules_diff.removed
    # The introspectors list already contains module names
    introspector_modules = introspectors

    not MapSet.disjoint?(MapSet.new(all_changed), MapSet.new(introspector_modules))
  end

  @spec find_module_vertices(Graph.t(), [module()]) :: [Clarity.Vertex.Module.t()]
  defp find_module_vertices(graph, module_names) do
    Graph.vertices(
      graph,
      {:and, {:==, :vertex_type, Clarity.Vertex.Module}, {:in, {:field, :module}, module_names}}
    )
  end

  @spec find_application_vertex(Graph.t(), Application.app()) ::
          Clarity.Vertex.Application.t() | nil
  defp find_application_vertex(graph, app) do
    Graph.get_vertex(graph, Util.id(Clarity.Vertex.Application, [app]))
  end
end
