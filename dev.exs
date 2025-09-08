Application.put_env(:phoenix, :serve_endpoints, true)

:erlang.system_flag(:backtrace_depth, 100)

Application.ensure_all_started(:atlas)

Task.start(fn ->
  children = [
    DemoWeb.Endpoint,
    {Phoenix.PubSub, [name: Demo.PubSub, adapter: Phoenix.PubSub.PG2]},
  ]

  {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)
  Process.sleep(:infinity)
end)
