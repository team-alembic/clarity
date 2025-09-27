defmodule Clarity.Server.Worker do
  @moduledoc false

  use GenServer

  @type option() :: {:clarity_server, GenServer.server()}
  @type options() :: [option()]

  defstruct [:clarity_server]

  @type t() :: %__MODULE__{
          clarity_server: GenServer.server()
        }

  @spec start_link(options()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl GenServer
  def init(opts) do
    clarity_server = Keyword.get(opts, :clarity_server, Clarity.Server)
    Clarity.subscribe(clarity_server)
    state = %__MODULE__{clarity_server: clarity_server}
    {:ok, state, {:continue, :pull_task}}
  end

  @impl GenServer
  def handle_continue(:pull_task, %{clarity_server: clarity_server} = state) do
    case Clarity.Server.pull_task(clarity_server, self()) do
      {:ok, task} ->
        execute_task(task, state)
        {:noreply, state, {:continue, :pull_task}}

      :empty ->
        # No dynamic subscription needed - we're always subscribed
        # Just hibernate until we receive :work_started event
        {:noreply, state, :hibernate}
    end
  end

  @impl GenServer
  def handle_info({:clarity, :work_started}, state) do
    {:noreply, state, {:continue, :pull_task}}
  end

  # Ignore other clarity events
  @impl GenServer
  def handle_info({:clarity, _event}, state) do
    {:noreply, state}
  end

  @spec execute_task(Clarity.Server.Task.t(), t()) :: :ok
  defp execute_task(task, %__MODULE__{clarity_server: clarity_server}) do
    # Call the introspector with vertex and graph from task
    result =
      try do
        task.introspector.introspect_vertex(task.vertex, task.graph)
      rescue
        UndefinedFunctionError ->
          # Introspector hasn't been updated yet
          []
      end

    Clarity.Server.ack_task(clarity_server, task.id, result, self())
  rescue
    error ->
      Clarity.Server.nack_task(clarity_server, task.id, error, self())
  catch
    kind, reason ->
      error = {kind, reason, __STACKTRACE__}

      Clarity.Server.nack_task(clarity_server, task.id, error, self())
  end
end
