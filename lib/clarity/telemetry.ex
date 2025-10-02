defmodule Clarity.Telemetry do
  @moduledoc false

  use TelemetryRegistry
  use GenServer

  telemetry_event(%{
    event: [:clarity, :introspection, :start],
    description: """
    Emitted when introspection of the application starts.

    This event marks the beginning of the introspection process where Clarity
    analyzes the application structure and dependencies.
    """,
    measurements: "%{monotonic_time: integer(), system_time: integer()}",
    metadata: "%{clarity_server: GenServer.server(), telemetry_span_context: reference()}"
  })

  telemetry_event(%{
    event: [:clarity, :introspection, :progress],
    description: """
    Emitted periodically during introspection to report progress.

    This event provides updates on the introspection process, including queue
    sizes and the number of vertices being processed.
    """,
    measurements: """
    %{
      duration: integer(),
      monotonic_time: integer(),
      system_time: integer(),
      future_queue: non_neg_integer(),
      requeue_queue: non_neg_integer(),
      in_progress: non_neg_integer(),
      total_vertices: non_neg_integer()
    }
    """,
    metadata: "%{clarity_server: GenServer.server(), telemetry_span_context: reference()}"
  })

  telemetry_event(%{
    event: [:clarity, :introspection, :stop],
    description: """
    Emitted when introspection of the application completes.

    This event marks the end of the introspection process.
    """,
    measurements: "%{duration: integer(), monotonic_time: integer(), system_time: integer()}",
    metadata: "%{clarity_server: GenServer.server(), telemetry_span_context: reference()}"
  })

  telemetry_event(%{
    event: [:clarity, :worker, :start],
    description: """
    Emitted when a worker starts processing a vertex.

    This event is emitted at the beginning of vertex processing in a worker
    process.
    """,
    measurements: "%{monotonic_time: integer(), system_time: integer()}",
    metadata: """
    %{
      clarity_server: GenServer.server(),
      worker: GenServer.server(),
      telemetry_span_context: reference(),
      introspector: module(),
      vertex_type: module()
    }
    """
  })

  telemetry_event(%{
    event: [:clarity, :worker, :stop],
    description: """
    Emitted when a worker finishes processing a vertex.

    This event is emitted after successful vertex processing, including the
    result type and entry count.
    """,
    measurements: """
    %{
      duration: integer(),
      monotonic_time: integer(),
      system_time: integer(),
      result_entry_count: non_neg_integer() | nil
    }
    """,
    metadata: """
    %{
      clarity_server: GenServer.server(),
      worker: GenServer.server(),
      telemetry_span_context: reference(),
      introspector: module(),
      vertex_type: module(),
      result_type: :ok | :unmet_dependencies
    }
    """
  })

  telemetry_event(%{
    event: [:clarity, :worker, :exception],
    description: """
    Emitted when a worker encounters an exception during vertex processing.

    This event is emitted when an error, exit, or throw occurs during vertex processing.
    """,
    measurements: "%{duration: integer(), monotonic_time: integer(), system_time: integer()}",
    metadata: """
    %{
      clarity_server: GenServer.server(),
      worker: GenServer.server(),
      telemetry_span_context: reference(),
      introspector: module(),
      vertex_type: module(),
      kind: :error | :exit | :throw,
      reason: term(),
      stacktrace: list()
    }
    """
  })

  Module.put_attribute(
    __MODULE__,
    :moduledoc,
    {__ENV__.line,
     """
     Telemetry integration for Clarity introspection and worker events.

     This module subscribes to Clarity events and emits corresponding telemetry
     events for monitoring and observability purposes.

     ## Events

     #{telemetry_docs()}

     ## Usage with Telemetry Metrics / Phoenix.LiveDashboard

     To monitor Clarity events in Phoenix.LiveDashboard, add these metrics to your
     telemetry module:

         defmodule MyApp.Telemetry do
           use Supervisor
           import Telemetry.Metrics

           def start_link(arg) do
             Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
           end

           def init(_arg) do
             children = [
               {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
             ]

             Supervisor.init(children, strategy: :one_for_one)
           end

           def metrics do
             [
               # Introspection Events
               summary("clarity.introspection.start.system_time",
                 unit: {:native, :millisecond}
               ),
               summary("clarity.introspection.stop.duration",
                 unit: {:native, :second}
               ),
               summary("clarity.introspection.progress.duration",
                 unit: {:native, :millisecond}
               ),
               summary("clarity.introspection.progress.future_queue"),
               summary("clarity.introspection.progress.requeue_queue"),
               summary("clarity.introspection.progress.in_progress"),
               summary("clarity.introspection.progress.total_vertices"),

               # Worker Events
               summary("clarity.worker.start.system_time",
                 unit: {:native, :millisecond}
               ),
               distribution("clarity.worker.stop.duration",
                 unit: {:native, :millisecond},
                 tags: [:vertex_type, :introspector],
                 tag_values: &%{&1 | worker: inspect(&1.worker)}
               ),
               counter("clarity.worker.slow.duration",
                 unit: {:native, :millisecond},
                 tags: [:vertex_type, :introspector],
                 tag_values: &%{&1 | worker: inspect(&1.worker)}
               ),
               summary("clarity.worker.exception.duration",
                 unit: {:native, :millisecond}
               )
             ]
           end

           defp periodic_measurements do
             []
           end
         end
     """}
  )

  defmodule State do
    @moduledoc false

    @enforce_keys [:clarity_server, :progress_ref, :progress_start]
    defstruct [:clarity_server, :progress_ref, :progress_start]

    @type t() :: %__MODULE__{
            clarity_server: GenServer.server(),
            progress_ref: reference(),
            progress_start: integer()
          }
  end

  @typedoc false
  @type option() :: {:clarity_server, GenServer.server()} | {:name, GenServer.name()}

  @typedoc false
  @type options() :: [option()]

  @typedoc false
  @type report_work_result_fun() :: ([Clarity.Introspector.entry()] | :unmet_dependencies -> :ok)

  @typedoc false
  @type report_work_exception_fun() ::
          (kind :: :error | :exit | :throw, reason :: term(), stacktrace :: list() -> :ok)

  @doc false
  @spec child_spec(options()) :: Supervisor.child_spec()
  def child_spec(opts), do: super(opts)

  @doc false
  @spec start_link(options()) :: GenServer.on_start()
  def start_link(opts) do
    gen_server_opts =
      opts
      |> Keyword.take([:name])
      |> Keyword.put_new(:name, __MODULE__)

    GenServer.start_link(__MODULE__, opts, gen_server_opts)
  end

  @impl GenServer
  def init(opts) do
    clarity_server = Keyword.get(opts, :clarity_server, Clarity.Server)

    Clarity.subscribe(clarity_server, ~w[work_started work_progress work_completed]a)

    # Setting up with default values to not break anything if we ever receive
    # a subset of events (for example, restart)
    {:ok,
     %State{
       clarity_server: clarity_server,
       progress_ref: make_ref(),
       progress_start: System.monotonic_time()
     }}
  end

  @impl GenServer
  def handle_info({:clarity, :work_started}, %State{} = state) do
    ref = make_ref()
    start_time = System.monotonic_time()

    :telemetry.execute(
      ~w[clarity introspection start]a,
      %{monotonic_time: start_time, system_time: :erlang.system_time()},
      %{clarity_server: state.clarity_server, telemetry_span_context: ref}
    )

    {:noreply, %{state | progress_ref: ref, progress_start: start_time}}
  end

  def handle_info({:clarity, {:work_progress, queue_info}}, %State{} = state) do
    time = System.monotonic_time()

    :telemetry.execute(
      ~w[clarity introspection progress]a,
      %{
        duration: time - state.progress_start,
        monotonic_time: time,
        system_time: :erlang.system_time(),
        future_queue: queue_info.future_queue,
        requeue_queue: queue_info.requeue_queue,
        in_progress: queue_info.in_progress,
        total_vertices: queue_info.total_vertices
      },
      %{clarity_server: state.clarity_server, telemetry_span_context: state.progress_ref}
    )

    {:noreply, state}
  end

  def handle_info({:clarity, :work_completed}, %State{} = state) do
    stop_time = System.monotonic_time()

    :telemetry.execute(
      ~w[clarity introspection stop]a,
      %{
        duration: stop_time - state.progress_start,
        monotonic_time: stop_time,
        system_time: :erlang.system_time()
      },
      %{clarity_server: state.clarity_server, telemetry_span_context: state.progress_ref}
    )

    {:noreply, state}
  end

  @doc false
  @spec report_work(GenServer.server(), GenServer.server(), Clarity.Server.Task.t()) ::
          {report_work_result_fun(), report_work_exception_fun()}
  def report_work(clarity_server, worker, task) do
    ref = make_ref()
    start_time = System.monotonic_time()

    :telemetry.execute(
      ~w[clarity worker start]a,
      %{monotonic_time: System.system_time(), system_time: :erlang.system_time()},
      %{
        clarity_server: clarity_server,
        worker: worker,
        telemetry_span_context: ref,
        introspector: task.introspector,
        vertex_type: task.vertex.__struct__
      }
    )

    report_stop = fn result ->
      stop_time = System.monotonic_time()

      :telemetry.execute(
        ~w[clarity worker stop]a,
        %{
          duration: stop_time - start_time,
          monotonic_time: stop_time,
          system_time: :erlang.system_time(),
          result_entry_count: if(is_list(result), do: length(result))
        },
        %{
          clarity_server: clarity_server,
          worker: worker,
          telemetry_span_context: ref,
          introspector: task.introspector,
          vertex_type: task.vertex.__struct__,
          result_type:
            case result do
              entries when is_list(entries) -> :ok
              :unmet_dependencies -> :unmet_dependencies
            end
        }
      )
    end

    report_exception = fn kind, reason, stacktrace ->
      stop_time = System.monotonic_time()

      :telemetry.execute(
        ~w[clarity worker exception]a,
        %{
          duration: stop_time - start_time,
          monotonic_time: stop_time,
          system_time: :erlang.system_time()
        },
        %{
          clarity_server: clarity_server,
          worker: worker,
          telemetry_span_context: ref,
          introspector: task.introspector,
          vertex_type: task.vertex.__struct__,
          kind: kind,
          reason: reason,
          stacktrace: stacktrace
        }
      )
    end

    {report_stop, report_exception}
  end
end
