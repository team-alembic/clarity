Application.put_env(:phoenix, :serve_endpoints, true)

:erlang.system_flag(:backtrace_depth, 100)

Application.ensure_all_started(:clarity)

Task.start(fn ->
  children = [
    {Phoenix.PubSub, [name: Demo.PubSub, adapter: Phoenix.PubSub.PG2]},
    {Task.Supervisor, name: Demo.TaskSupervisor},
    Demo.Notifications.Supervisor,
    DemoWeb.Endpoint
  ]

  {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one, name: Demo.Supervisor)
  Process.sleep(:infinity)
end)
