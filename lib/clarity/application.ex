defmodule Clarity.Application do
  @moduledoc false

  use Application

  case Mix.env() do
    :test ->
      @children [DemoWeb.Endpoint]

    _env ->
      @children [
        Clarity.Server,
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
