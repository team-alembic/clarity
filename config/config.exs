import Config

config :clarity, introspector_applications: [:clarity, :ash, :spark]

config :esbuild,
  version: "0.25.10",
  default: [
    args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.14",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

case config_env() do
  env when env in [:dev, :test] ->
    config :clarity, DemoWeb.Endpoint,
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
          ~r"lib/clarity/(live|views|pages|components)/.*(ex)$",
          ~r"lib/clarity/templates/.*(eex)$"
        ]
      ]

    config :clarity,
      ash_domains: [Demo.Accounts.Domain]

    config :logger, level: :debug

  _ ->
    :ok
end
