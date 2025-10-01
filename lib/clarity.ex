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

  @type event() ::
          :work_started
          | :work_completed
          | {:work_progress, queue_info()}

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

  @enforce_keys [:graph, :status, :queue_info]
  defstruct [:graph, :status, :queue_info]

  @doc """
  Subscribe to clarity events. Returns an unsubscribe function.
  """
  @spec subscribe(GenServer.server()) :: unsubscribe()
  def subscribe(server \\ Clarity.Server) do
    GenServer.call(server, :subscribe)
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
    case GenServer.call(server, :get) do
      %__MODULE__{status: :done} = clarity ->
        clarity

      %__MODULE__{status: :working} ->
        # Subscribe and wait for work to complete
        unsubscribe = subscribe(server)

        try do
          receive do
            {:clarity, :work_completed} ->
              GenServer.call(server, :get)
          after
            60_000 ->
              raise "Timeout waiting for work to complete"
          end
        after
          unsubscribe.()
        end
    end
  end
end
