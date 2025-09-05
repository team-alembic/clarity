Application.put_env(:atlas, DemoWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "Hu4qQN3iKzTV4fJxhorPQlA/osH9fAMtbtjVS58PFgfw3ja5Z18Q/WSNR9wP4OfW",
  live_view: [signing_salt: "hMegieSe"],
  http: [port: System.get_env("PORT", "4000")],
  debug_errors: true,
  check_origin: false,
  pubsub_server: Demo.PubSub,
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]}
  ],
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/atlas/(live|views|pages|components)/.*(ex)$",
      ~r"lib/atlas/templates/.*(eex)$"
    ]
  ]
)

defmodule DemoWeb.Router do
  use Phoenix.Router

  pipeline :browser do
    plug :fetch_session
    plug :fetch_query_params
  end

  scope "/" do
    pipe_through :browser
    import Atlas.Router

    atlas("/")
  end
end

defmodule DemoWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :atlas

  socket "/live", Phoenix.LiveView.Socket
  socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket

  plug Plug.Static,
    at: "/",
    from: :atlas,
    gzip: true,
    only: Atlas.Web.static_paths()

  plug Phoenix.LiveReloader
  plug Phoenix.CodeReloader

  plug Plug.Session,
    store: :cookie,
    key: "_live_view_key",
    signing_salt: "/VEDsdfsffMnp5"

  plug Plug.RequestId
  plug DemoWeb.Router
end

Application.put_env(:phoenix, :serve_endpoints, true)
  :erlang.system_flag(:backtrace_depth, 100)

Task.start(fn ->
  children = [
    DemoWeb.Endpoint,
    {Phoenix.PubSub, [name: Demo.PubSub, adapter: Phoenix.PubSub.PG2]},
  ]

  {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)
  Process.sleep(:infinity)
end)
