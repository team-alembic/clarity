defmodule Clarity.Advisory.Source do
  @moduledoc """
  Downloads the public OSV advisory database for the Hex ecosystem and matches
  the project's dependencies against it locally.

  The dependency list never leaves the machine: the only egress is fetching a
  public bulk archive (`osv-vulnerabilities/Hex/all.zip`). Matching happens here.

  Following the tzdata approach, advisories are persisted to a DETS table under
  the configured cache path and mirrored into a public ETS table for concurrent,
  lock-free reads via `advisories_for/2`. A refresh runs on a timer (and on boot
  only when the cache is stale), rewrites both tables, and asks the server to
  re-introspect so advisory vertices appear in the graph.
  """

  use GenServer

  alias Clarity.Advisory
  alias Clarity.Config

  require Logger

  @ets __MODULE__
  @meta_key :__last_refreshed__
  @attempted_key :__attempted__

  @doc false
  @spec start_link(GenServer.options()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    opts = Keyword.put_new(opts, :name, __MODULE__)
    {init_opts, opts} = Keyword.split(opts, [:cache_path])
    GenServer.start_link(__MODULE__, init_opts, opts)
  end

  @doc """
  Advisories affecting `name` at `version`, read from the ETS mirror.

  Returns `[]` when the source isn't running (e.g. in tests) or has no data.
  """
  @spec advisories_for(atom() | String.t(), charlist() | String.t()) :: [Advisory.t()]
  def advisories_for(name, version) do
    name = to_string(name)
    version = to_string(version)

    case lookup({:package, name}) do
      [{_key, advisories}] -> Enum.filter(advisories, &Advisory.affects_version?(&1, version))
      _missing -> []
    end
  end

  @doc "When the advisory database was last refreshed, or `nil` if never."
  @spec last_refreshed_at() :: DateTime.t() | nil
  def last_refreshed_at do
    case lookup(@meta_key) do
      [{_key, %DateTime{} = at}] -> at
      _missing -> nil
    end
  end

  @doc """
  Whether advisory results are settled enough to introspect.

  True when advisories are disabled, when a refresh has succeeded (data present),
  or when at least one refresh has been attempted this session — so an offline or
  failing fetch yields empty results rather than blocking the graph forever.
  """
  @spec ready?() :: boolean()
  def ready? do
    not Config.advisories_enabled?() or last_refreshed_at() != nil or attempted?()
  end

  # sobelow_skip ["Traversal.FileModule"]
  # cache_path comes from application config, not user input (same source Cache uses).
  @impl GenServer
  def init(opts) do
    cache_path = Keyword.get(opts, :cache_path, Config.cache_path())
    File.mkdir_p!(cache_path)
    dets_path = Path.join(cache_path, "advisories.dets")

    {:ok, dets} = :dets.open_file(__MODULE__, file: String.to_charlist(dets_path), type: :set)
    :ets.new(@ets, [:named_table, :set, :public, read_concurrency: true])
    :dets.to_ets(dets, @ets)

    state = %{dets: dets}

    if Config.advisories_enabled?() do
      Process.send_after(self(), :refresh, refresh_delay())
    end

    {:ok, state}
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
    case fetch_advisories_by_package() do
      {:ok, by_package} ->
        store(dets, by_package)
        Logger.info("Clarity: refreshed #{map_size(by_package)} advised Hex packages")

      {:error, reason} ->
        Logger.warning("Clarity: advisory refresh failed (#{inspect(reason)}); keeping cache")
    end

    :ets.insert(@ets, {@attempted_key, true})
    :ok
  end

  @spec store(:dets.tab_name(), %{String.t() => [Advisory.t()]}) :: :ok
  defp store(dets, by_package) do
    :ets.delete_all_objects(@ets)
    :dets.delete_all_objects(dets)

    objects =
      [
        {@meta_key, DateTime.utc_now()}
        | Enum.map(by_package, fn {name, advisories} -> {{:package, name}, advisories} end)
      ]

    :ets.insert(@ets, objects)
    :dets.insert(dets, objects)
    :dets.sync(dets)
  end

  @spec fetch_advisories_by_package() :: {:ok, %{String.t() => [Advisory.t()]}} | {:error, term()}
  defp fetch_advisories_by_package do
    with {:ok, zip} <- download(Config.advisories_source_url()),
         {:ok, entries} <- :zip.unzip(zip, [:memory]) do
      by_package =
        entries
        |> Enum.flat_map(fn {_filename, contents} -> parse_entry(contents) end)
        |> Enum.group_by(& &1.package)

      {:ok, by_package}
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

  @spec parse_entry(binary()) :: [Advisory.t()]
  defp parse_entry(contents) do
    case JSON.decode(contents) do
      {:ok, osv} -> Advisory.from_osv(osv)
      {:error, _reason} -> []
    end
  end

  @spec attempted?() :: boolean()
  defp attempted? do
    case lookup(@attempted_key) do
      [{_key, true}] -> true
      _missing -> false
    end
  end

  @spec refresh_delay() :: non_neg_integer()
  defp refresh_delay do
    case last_refreshed_at() do
      nil ->
        0

      at ->
        interval = Config.advisories_refresh_interval()
        elapsed = DateTime.diff(DateTime.utc_now(), at, :millisecond)
        max(interval - elapsed, 0)
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
