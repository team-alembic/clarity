defmodule Clarity.Graph.CacheTest do
  use ExUnit.Case, async: true

  alias Clarity.Graph
  alias Clarity.Graph.Cache
  alias Clarity.Server

  @moduletag :tmp_dir

  describe "load/1" do
    test "returns error when cache directory doesn't exist", %{tmp_dir: tmp_dir} do
      cache_path = Path.join(tmp_dir, "nonexistent")

      cache =
        start_supervised!({Cache, clarity_server: self(), cache_path: cache_path, name: __MODULE__.LoadNoCache})

      assert {:error, _} = Cache.load(cache)
    end

    test "returns error when cache is invalid due to version mismatch", %{tmp_dir: tmp_dir} do
      cache_path = Path.join(tmp_dir, "version_mismatch")

      cache =
        start_supervised!({Cache, clarity_server: self(), cache_path: cache_path, name: __MODULE__.LoadVersionMismatch})

      graph = Graph.new()

      :ok = File.mkdir_p(cache_path)
      :ok = Graph.persist(graph, cache_path)

      metadata = %{
        version: "0.0.0",
        clarity_config_hash: :erlang.phash2(Application.get_all_env(:clarity)),
        app_configs_hash: app_configs_hash()
      }

      metadata_path = Path.join(cache_path, "metadata.etf")
      File.write!(metadata_path, :erlang.term_to_binary(metadata))

      assert {:error, {:invalid, :version_mismatch}} = Cache.load(cache)
    end

    test "returns error when cache is invalid due to clarity config change", %{tmp_dir: tmp_dir} do
      cache_path = Path.join(tmp_dir, "config_changed")

      cache =
        start_supervised!({Cache, clarity_server: self(), cache_path: cache_path, name: __MODULE__.LoadConfigChanged})

      graph = Graph.new()

      :ok = File.mkdir_p(cache_path)
      :ok = Graph.persist(graph, cache_path)

      clarity_version = :clarity |> Application.spec(:vsn) |> List.to_string()

      metadata = %{
        version: clarity_version,
        clarity_config_hash: 999_999,
        app_configs_hash: app_configs_hash()
      }

      metadata_path = Path.join(cache_path, "metadata.etf")
      File.write!(metadata_path, :erlang.term_to_binary(metadata))

      assert {:error, {:invalid, :clarity_config_changed}} = Cache.load(cache)
    end

    test "returns error when cache is invalid due to app config change", %{tmp_dir: tmp_dir} do
      cache_path = Path.join(tmp_dir, "app_config_changed")

      cache =
        start_supervised!({Cache, clarity_server: self(), cache_path: cache_path, name: __MODULE__.LoadAppConfigChanged})

      graph = Graph.new()

      :ok = File.mkdir_p(cache_path)
      :ok = Graph.persist(graph, cache_path)

      clarity_version = :clarity |> Application.spec(:vsn) |> List.to_string()

      metadata = %{
        version: clarity_version,
        clarity_config_hash: :erlang.phash2(Application.get_all_env(:clarity)),
        app_configs_hash: 999_999
      }

      metadata_path = Path.join(cache_path, "metadata.etf")
      File.write!(metadata_path, :erlang.term_to_binary(metadata))

      assert {:error, {:invalid, :app_configs_changed}} = Cache.load(cache)
    end

    test "returns ok with graph when cache is valid", %{tmp_dir: tmp_dir} do
      cache_path = Path.join(tmp_dir, "valid_cache")

      cache =
        start_supervised!({Cache, clarity_server: self(), cache_path: cache_path, name: __MODULE__.LoadValid})

      graph = Graph.new()

      :ok = File.mkdir_p(cache_path)
      :ok = Graph.persist(graph, cache_path)

      clarity_version = :clarity |> Application.spec(:vsn) |> List.to_string()

      metadata = %{
        version: clarity_version,
        clarity_config_hash: :erlang.phash2(Application.get_all_env(:clarity)),
        app_configs_hash: app_configs_hash()
      }

      metadata_path = Path.join(cache_path, "metadata.etf")
      File.write!(metadata_path, :erlang.term_to_binary(metadata))

      assert {:ok, loaded_graph} = Cache.load(cache)
      assert %Graph{} = loaded_graph
    end
  end

  describe "persistence on work_completed" do
    test "persists graph when work_completed event is received", %{tmp_dir: tmp_dir} do
      cache_path = Path.join(tmp_dir, "persist_test")

      server = start_supervised!({Server, name: __MODULE__.PersistServer})

      _cache =
        start_supervised!({Cache, clarity_server: server, cache_path: cache_path, name: __MODULE__.PersistCache})

      Clarity.subscribe(server, :work_completed)

      task = Server.pull_task(server)

      case task do
        {:ok, task} ->
          Server.ack_task(server, task.id, [])

        :empty ->
          :ok
      end

      assert_receive {:clarity, :work_completed}, 5000

      Process.sleep(1000)

      metadata_path = Path.join(cache_path, "metadata.etf")

      assert File.exists?(metadata_path)

      {:ok, binary} = File.read(metadata_path)
      metadata = :erlang.binary_to_term(binary)

      clarity_version = :clarity |> Application.spec(:vsn) |> List.to_string()

      assert metadata.version == clarity_version
      assert is_integer(metadata.clarity_config_hash)
      assert is_integer(metadata.app_configs_hash)
    end

    test "logs warning when persistence fails", %{tmp_dir: tmp_dir} do
      import ExUnit.CaptureLog

      cache_path = Path.join(tmp_dir, "persist_fail_test")

      server = start_supervised!({Server, name: __MODULE__.PersistFailServer})

      _cache =
        start_supervised!({Cache, clarity_server: server, cache_path: cache_path, name: __MODULE__.PersistFailCache})

      Clarity.subscribe(server, :work_completed)

      File.mkdir_p!(cache_path)
      File.chmod!(cache_path, 0o000)

      task = Server.pull_task(server)

      case task do
        {:ok, task} ->
          Server.ack_task(server, task.id, [])

        :empty ->
          :ok
      end

      log =
        capture_log(fn ->
          assert_receive {:clarity, :work_completed}, 5000
          Process.sleep(100)
        end)

      assert log =~ "Failed to persist graph cache"

      File.chmod!(cache_path, 0o755)
    end
  end

  describe "subscription in init" do
    test "subscribes to work_completed on init", %{tmp_dir: tmp_dir} do
      cache_path = Path.join(tmp_dir, "subscribe_test")

      server = start_supervised!({Server, name: __MODULE__.SubscribeServer})

      cache =
        start_supervised!({Cache, clarity_server: server, cache_path: cache_path, name: __MODULE__.SubscribeCache})

      task = Server.pull_task(server)

      case task do
        {:ok, task} ->
          Server.ack_task(server, task.id, [])

        :empty ->
          :ok
      end

      send(cache, {:clarity, :work_completed})

      Process.sleep(100)

      metadata_path = Path.join(cache_path, "metadata.etf")

      assert File.exists?(metadata_path)
    end
  end

  @spec app_configs_hash() :: integer()
  defp app_configs_hash do
    Application.loaded_applications()
    |> Enum.map(&elem(&1, 0))
    |> Enum.flat_map(fn app ->
      app
      |> Application.get_all_env()
      |> Enum.filter(fn {key, _} ->
        key in [:clarity_introspectors, :clarity_content_providers, :clarity_perspective_lensmakers]
      end)
    end)
    |> :erlang.phash2()
  end
end
