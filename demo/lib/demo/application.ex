defmodule Demo.Application do
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: Demo.PubSub},
      {Task.Supervisor, name: Demo.TaskSupervisor},
      Demo.Notifications.Supervisor,
      DemoWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Demo.Supervisor)
  end
end
