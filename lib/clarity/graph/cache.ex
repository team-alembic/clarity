defmodule Clarity.Graph.Cache do
  @moduledoc false

  use GenServer

  alias Clarity.Graph

  require Logger

  defmodule State do
    @moduledoc false

    @enforce_keys [:clarity_server, :cache_path]
    defstruct [:clarity_server, :cache_path]

    @type t() :: %__MODULE__{
            clarity_server: GenServer.server(),
            cache_path: Path.t()
          }
  end

  @doc false
  @spec start_link(opts :: Keyword.t()) :: GenServer.on_start()
  def start_link(opts) do
    {init_opts, gen_server_opts} = Keyword.split(opts, [:clarity_server, :cache_path])

    clarity_server = Keyword.fetch!(init_opts, :clarity_server)
    cache_path = Keyword.get(init_opts, :cache_path, Clarity.Config.cache_path())

    gen_server_opts = Keyword.put_new(gen_server_opts, :name, __MODULE__)

    GenServer.start_link(__MODULE__, {clarity_server, cache_path}, gen_server_opts)
  end

  @doc """
  Loads the cached graph if valid, otherwise returns an error.

  Returns `{:ok, graph}` if cache exists and is valid.
  Returns `{:error, reason}` if cache is invalid, missing, or cannot be loaded.
  """
  @spec load(GenServer.server()) :: {:ok, Graph.t()} | {:error, term()}
  def load(server \\ __MODULE__) do
    GenServer.call(server, :load)
  after
    delete_ets_transfer_messages()
  end

  @impl GenServer
  def init({clarity_server, cache_path}) do
    Clarity.subscribe(clarity_server, :work_completed)
    state = %State{clarity_server: clarity_server, cache_path: cache_path}
    {:ok, state}
  end

  @impl GenServer
  def handle_call(:load, from, state) do
    {caller_pid, _tag} = from

    result =
      with {:ok, graph} <- Graph.load(state.cache_path),
           :ok <- validate_cache(state.cache_path) do
        Graph.handover(graph, caller_pid)
      end

    {:reply, result, state}
  end

  @impl GenServer
  def handle_info({:clarity, :work_completed}, state) do
    %Clarity{graph: graph} = Clarity.get(state.clarity_server, :partial)

    case persist(graph, state.cache_path) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("Failed to persist graph cache: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  @spec persist(Graph.t(), Path.t()) :: :ok | {:error, term()}
  defp persist(graph, cache_path) do
    with :ok <- File.mkdir_p(cache_path),
         :ok <- Graph.persist(graph, cache_path) do
      persist_metadata(cache_path)
    end
  end

  @spec persist_metadata(Path.t()) :: :ok | {:error, File.posix()}
  defp persist_metadata(cache_path) do
    metadata = %{
      version: clarity_version(),
      clarity_config_hash: clarity_config_hash(),
      app_configs_hash: app_configs_hash()
    }

    metadata_path = Path.join(cache_path, "metadata.etf")
    binary = :erlang.term_to_binary(metadata)
    File.write(metadata_path, binary)
  end

  @spec validate_cache(Path.t()) :: :ok | {:error, {:invalid, term()}}
  defp validate_cache(cache_path) do
    metadata_path = Path.join(cache_path, "metadata.etf")

    with {:ok, binary} <- File.read(metadata_path),
         metadata = :erlang.binary_to_term(binary),
         :ok <- validate_version(metadata),
         :ok <- validate_clarity_config(metadata),
         :ok <- validate_app_configs(metadata) do
      :ok
    else
      {:error, reason} -> {:error, {:invalid, reason}}
    end
  end

  @spec validate_version(map()) :: :ok | {:error, :version_mismatch}
  defp validate_version(%{version: version}) do
    if version == clarity_version() do
      :ok
    else
      {:error, :version_mismatch}
    end
  end

  @spec validate_clarity_config(map()) :: :ok | {:error, :clarity_config_changed}
  defp validate_clarity_config(%{clarity_config_hash: hash}) do
    if hash == clarity_config_hash() do
      :ok
    else
      {:error, :clarity_config_changed}
    end
  end

  @spec validate_app_configs(map()) :: :ok | {:error, :app_configs_changed}
  defp validate_app_configs(%{app_configs_hash: hash}) do
    if hash == app_configs_hash() do
      :ok
    else
      {:error, :app_configs_changed}
    end
  end

  @spec clarity_version() :: String.t()
  defp clarity_version do
    :clarity |> Application.spec(:vsn) |> List.to_string()
  end

  @spec clarity_config_hash() :: integer()
  defp clarity_config_hash do
    :erlang.phash2(Application.get_all_env(:clarity))
  end

  @spec app_configs_hash() :: integer()
  defp app_configs_hash do
    Application.loaded_applications()
    |> Enum.map(&elem(&1, 0))
    |> Enum.flat_map(fn app ->
      app
      |> Application.get_all_env()
      |> Enum.filter(fn {key, _} ->
        key in [
          :clarity_introspectors,
          :clarity_content_providers,
          :clarity_perspective_lensmakers
        ]
      end)
    end)
    |> :erlang.phash2()
  end

  @spec delete_ets_transfer_messages(non_neg_integer()) :: :ok
  defp delete_ets_transfer_messages(count \\ 12)
  defp delete_ets_transfer_messages(0), do: :ok

  defp delete_ets_transfer_messages(count) do
    receive do
      {:"ETS-TRANSFER", _ref, _pid, :graph_handover} ->
        delete_ets_transfer_messages(count - 1)
    after
      0 ->
        :ok
    end
  end
end
