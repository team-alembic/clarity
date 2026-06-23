import Config

config :esbuild,
  version: "0.25.10",
  default: [
    args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :mdex_native, syntax_highlighter: :lumis

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
      adapter: Bandit.PhoenixAdapter,
      url: [host: "localhost"],
      secret_key_base: "Hu4qQN3iKzTV4fJxhorPQlA/osH9fAMtbtjVS58PFgfw3ja5Z18Q/WSNR9wP4OfW",
      live_view: [signing_salt: "hMegieSe"],
      http: [port: System.get_env("PORT", "4000")],
      debug_errors: true,
      check_origin: false,
      pubsub_server: Demo.PubSub,
      watchers: [
        esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=linked --watch)]},
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

    config :clarity, auto_start?: false

    config :logger, level: :debug

  _ ->
    :ok
end

if Mix.env() == :dev do
  config :git_ops,
    mix_project: Clarity.MixProject,
    github_handle_lookup?: true,
    repository_url: "https://github.com/team-alembic/clarity",
    # Instructs the tool to manage your mix version in your `mix.exs` file
    # See below for more information
    manage_mix_version?: true,
    # Instructs the tool to manage the version in your README.md
    # Pass in `true` to use `"README.md"` or a string to customize
    manage_readme_version: "README.md",
    version_tag_prefix: "v"
end
