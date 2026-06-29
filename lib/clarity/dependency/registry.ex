defmodule Clarity.Dependency.Registry do
  @moduledoc """
  Downloads the bulk Hex registry and derives each dependency's version status
  (latest stable version and retired versions) for local matching.

  Like `Clarity.Advisory.Source`, the dependency list never leaves the machine —
  only the public, signed bulk registry is fetched. The payload's hexpm
  signature is verified with `hex_core` before decoding. Results are persisted to
  a DETS table with an ETS read-through, refreshed on the shared supply-chain
  timer (and on boot only when stale).
  """

  use GenServer

  alias Clarity.Config
  alias Clarity.Dependency

  require Logger

  @ets __MODULE__
  @attempted_key :__attempted__
  @refreshed_key :__last_refreshed__

  @doc false
  @spec start_link(GenServer.options()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    opts = Keyword.put_new(opts, :name, __MODULE__)
    {init_opts, opts} = Keyword.split(opts, [:cache_path])
    GenServer.start_link(__MODULE__, init_opts, opts)
  end

  @doc """
  Version status for `name`, or `nil` when unknown.

  Returns `nil` when the registry isn't running (e.g. in tests) or has no entry.
  """
  @spec summary(atom() | String.t()) :: Dependency.summary() | nil
  def summary(name) do
    case lookup({:package, to_string(name)}) do
      [{_key, summary}] -> summary
      _missing -> nil
    end
  end

  @doc "Whether registry results are settled enough to render (see `Clarity.Advisory.Source`)."
  @spec ready?() :: boolean()
  def ready? do
    not Config.advisories_enabled?() or refreshed?() or attempted?()
  end

  @impl GenServer
  # sobelow_skip ["Traversal.FileModule"]
  # cache_path comes from application config, not user input (same source Cache uses).
  def init(opts) do
    cache_path = Keyword.get(opts, :cache_path, Config.cache_path())
    File.mkdir_p!(cache_path)
    dets_path = Path.join(cache_path, "hex_registry.dets")

    {:ok, dets} = :dets.open_file(__MODULE__, file: String.to_charlist(dets_path), type: :set)
    :ets.new(@ets, [:named_table, :set, :public, read_concurrency: true])
    :dets.to_ets(dets, @ets)

    if Config.advisories_enabled?() do
      Process.send_after(self(), :refresh, refresh_delay())
    end

    {:ok, %{dets: dets}}
  end

  @impl GenServer
  def handle_info(:refresh, state) do
    refresh(state)
    Process.send_after(self(), :refresh, Config.advisories_refresh_interval())
    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  @impl GenServer
  def terminate(_reason, %{dets: dets}), do: :dets.close(dets)

  @spec refresh(map()) :: :ok
  defp refresh(%{dets: dets}) do
    case fetch_summaries() do
      {:ok, summaries} ->
        store(dets, summaries)
        Logger.info("Clarity: refreshed version status for #{map_size(summaries)} Hex packages")

      {:error, reason} ->
        Logger.warning("Clarity: Hex registry refresh failed (#{inspect(reason)}); keeping cache")
    end

    :ets.insert(@ets, {@attempted_key, true})
    :ok
  end

  @spec store(:dets.tab_name(), %{String.t() => Dependency.summary()}) :: :ok
  defp store(dets, summaries) do
    :ets.delete_all_objects(@ets)
    :dets.delete_all_objects(dets)

    objects =
      [
        {@refreshed_key, DateTime.utc_now()}
        | Enum.map(summaries, fn {name, summary} -> {{:package, name}, summary} end)
      ]

    :ets.insert(@ets, objects)
    :dets.insert(dets, objects)
    :dets.sync(dets)
  end

  @spec fetch_summaries() :: {:ok, %{String.t() => Dependency.summary()}} | {:error, term()}
  defp fetch_summaries do
    public_key = :hex_core.default_config().repo_public_key

    with {:ok, compressed} <- download(Config.hex_registry_url()),
         {:ok, payload} <-
           :hex_registry.decode_and_verify_signed(:zlib.gunzip(compressed), public_key),
         {:ok, %{packages: packages}} <- :hex_registry.decode_versions(payload, "hexpm") do
      summaries =
        Map.new(packages, fn package -> {package.name, Dependency.summarise(package)} end)

      {:ok, summaries}
    end
  end

  @spec download(String.t()) :: {:ok, binary()} | {:error, term()}
  defp download(url) do
    case Req.get(url, decode_body: false) do
      {:ok, %Req.Response{status: 200, body: body}} -> {:ok, body}
      {:ok, %Req.Response{status: status}} -> {:error, {:http_status, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec refresh_delay() :: non_neg_integer()
  defp refresh_delay do
    case lookup(@refreshed_key) do
      [{_key, %DateTime{} = at}] ->
        elapsed = DateTime.diff(DateTime.utc_now(), at, :millisecond)
        max(Config.advisories_refresh_interval() - elapsed, 0)

      _missing ->
        0
    end
  end

  @spec refreshed?() :: boolean()
  defp refreshed?, do: match?([{_key, %DateTime{}}], lookup(@refreshed_key))

  @spec attempted?() :: boolean()
  defp attempted? do
    case lookup(@attempted_key) do
      [{_key, true}] -> true
      _missing -> false
    end
  end

  @spec lookup(term()) :: [tuple()]
  defp lookup(key) do
    case :ets.whereis(@ets) do
      :undefined -> []
      _reference -> :ets.lookup(@ets, key)
    end
  end
end
