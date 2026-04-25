defmodule Demo.Notifications.Supervisor do
  @moduledoc """
  Top-level supervisor for the demo notifications subsystem.

  Children:
    * `Demo.Notifications.Dispatcher` - GenServer that fans messages out
      to delivery channels.
    * `Demo.Notifications.Queue` - GenServer that buffers undelivered
      messages.
    * `Demo.Notifications.TaskSupervisor` - Task.Supervisor used for
      one-off delivery jobs.
    * `Demo.Notifications.Registry` - Registry tracking active
      subscriber processes.
  """

  use Supervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl Supervisor
  def init(_opts) do
    children = [
      {Registry, keys: :unique, name: Demo.Notifications.Registry},
      {Task.Supervisor, name: Demo.Notifications.TaskSupervisor},
      Demo.Notifications.Queue,
      Demo.Notifications.Dispatcher
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
