defmodule Clarity.Application do
  @moduledoc false

  use Application

  alias Clarity.Config
  alias Clarity.Docs
  alias Clarity.Graph.Cache
  alias Clarity.Graph.Memo
  alias Clarity.ModuleCache
  alias Clarity.Tooltip
  alias Clarity.Vertex.Util

  case Mix.env() do
    :test ->
      @children [
        {Registry, keys: :duplicate, name: Clarity.PubSub}
      ]

    _env ->
      @children [
        {Task, &Clarity.Protocols.consolidate/0},
        {Registry, keys: :duplicate, name: Clarity.PubSub},
        {Clarity.Telemetry, clarity_server: Clarity.Server},
        {Cache, clarity_server: Clarity.Server, cache_path: Config.cache_path(), name: Cache},
        Clarity.Advisory.Source,
        Clarity.Dependency.Registry,
        {Clarity.Server, cache: Cache, auto_start?: Config.auto_start?()},
        {PartitionSupervisor,
         child_spec: {Clarity.Server.Worker, clarity_server: Clarity.Server},
         name: Clarity.WorkerPartitionSupervisor}
      ]
  end

  @impl Application
  def start(_type, _args) do
    Util.create_segment_cache()
    Config.create_module_application_cache()
    Docs.create_cache()
    Memo.create_table()
    ModuleCache.create_table()
    Tooltip.create_cache()

    Supervisor.start_link(@children, strategy: :one_for_one, name: Clarity.Supervisor)
  end
end
