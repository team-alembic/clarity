readme_path = Path.join(__DIR__, "../README.md")

readme_content =
  readme_path
  |> File.read!()
  |> String.replace(~r/<!-- ex_doc_ignore_start -->.*?<!-- ex_doc_ignore_end -->/s, "")

defmodule Clarity do
  @moduledoc """
  #{readme_content}
  """

  @external_resource readme_path

  @type unsubscribe() :: (-> :ok)

  @type queue_info() :: %{
          future_queue: non_neg_integer(),
          requeue_queue: non_neg_integer(),
          in_progress: non_neg_integer(),
          total_vertices: non_neg_integer()
        }

  @typedoc """
  - `:work_started` - Emitted when work starts
  - `:work_completed` - Emitted when all work is completed
  - `{:work_progress, queue_info()}` - Emitted periodically with current queue info

  Topics starting with `:__` are internal.
  """
  @type event() ::
          :work_started
          | :work_completed
          | {:work_progress, queue_info()}
          | :__restart_pulling__

  @type status() :: :working | :done

  @type modules_diff() :: %{
          changed: [module()],
          added: [module()],
          removed: [module()]
        }

  @type t() :: %__MODULE__{
          graph: Clarity.Graph.t(),
          status: status(),
          queue_info: queue_info()
        }

  @typedoc """
  - `:work_started` - Emitted when work starts
  - `:work_completed` - Emitted when all work is completed
  - `:work_progress` - Emitted periodically with current queue info

  Topics starting with `:__` are internal.
  """
  @type subscription_topic() ::
          :work_started
          | :work_completed
          | :work_progress
          | :__restart_pulling__

  @enforce_keys [:graph, :status, :queue_info]
  defstruct [:graph, :status, :queue_info]

  @doc """
  Subscribe to clarity events. Returns an unsubscribe function.

  ## Examples

      # Subscribe to specific events only
      unsubscribe = Clarity.subscribe([:work_started, :work_completed])

      # Unsubscribe later
      unsubscribe.()
  """
  @spec subscribe(GenServer.server(), subscription_topic() | [subscription_topic()]) ::
          unsubscribe()
  def subscribe(server \\ Clarity.Server, topics) do
    topics = List.wrap(topics)

    Enum.each(topics, fn topic ->
      {:ok, _} = Registry.register(Clarity.PubSub, {server, topic}, [])
    end)

    fn ->
      Enum.each(topics, fn topic ->
        Registry.unregister(Clarity.PubSub, {server, topic})
      end)
    end
  end

  @doc """
  Start introspection process.

  ## Options

  - `:full` - Full introspection, clears graph and re-introspects everything
  - `{:incremental, app, modules_diff}` - Incremental introspection based on module changes for specific app
  - `[module()]` - Introspect specific modules (legacy support)
  """
  @spec introspect(
          GenServer.server(),
          :full | {:incremental, Application.app(), modules_diff()} | [module()]
        ) :: :ok
  def introspect(server \\ Clarity.Server, scope \\ :full) do
    GenServer.cast(server, {:introspect, scope})
  end

  @doc """
  Get current clarity state.

  For `:partial` mode, returns the current state immediately.
  For `:complete` mode, waits for all work to complete before returning the final state.
  """
  @spec get(GenServer.server(), :partial | :complete) :: t()
  def get(server \\ Clarity.Server, mode \\ :partial)

  def get(server, :partial) do
    GenServer.call(server, :get)
  end

  def get(server, :complete) do
    unsubscribe = subscribe(server, :work_completed)

    try do
      case GenServer.call(server, :get) do
        %Clarity{status: :done} = clarity ->
          clarity

        _clarity ->
          receive do
            {:clarity, :work_completed} ->
              GenServer.call(server, :get)
          after
            60_000 ->
              raise "Timeout waiting for work to complete"
          end
      end
    after
      unsubscribe.()
    end
  end
end
