defmodule Clarity.Application do
  @moduledoc false

  use Application

  alias Clarity.Graph.Cache

  case Mix.env() do
    :test ->
      @children [
        {Registry, keys: :duplicate, name: Clarity.PubSub},
        DemoWeb.Endpoint
      ]

    _env ->
      @children [
        {Registry, keys: :duplicate, name: Clarity.PubSub},
        {Clarity.Telemetry, clarity_server: Clarity.Server},
        {Cache,
         clarity_server: Clarity.Server, cache_path: Clarity.Config.cache_path(), name: Cache},
        {Clarity.Server, cache: Cache, auto_start?: Clarity.Config.auto_start?()},
        {PartitionSupervisor,
         child_spec: {Clarity.Server.Worker, clarity_server: Clarity.Server},
         name: Clarity.WorkerPartitionSupervisor}
      ]
  end

  @impl Application
  def start(_type, _args) do
    Supervisor.start_link(@children, strategy: :one_for_one, name: Clarity.Supervisor)
  end
end
