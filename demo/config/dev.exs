import Config

# Clarity is developed alongside this app, so rebuild its assets with the
# profiles from its own config and reload its code as well as the demo's.
clarity_config = Config.Reader.read!(Path.expand("../../config/config.exs", __DIR__), env: :dev)

config :demo, DemoWeb.Endpoint,
  code_reloader: true,
  debug_errors: true,
  reloadable_apps: [:demo, :clarity],
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=linked --watch)]},
    tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]}
  ],
  live_reload: [
    patterns: [
      ~r"priv/static/assets/.*(js|css)$",
      ~r"lib/clarity/(pages|components)/.*(ex)$",
      ~r"lib/demo_web/.*(ex)$"
    ]
  ]

config :esbuild, clarity_config[:esbuild]

config :phoenix, :plug_init_mode, :runtime
config :phoenix, :stacktrace_depth, 20

config :phoenix_live_reload, :dirs, [
  "",
  Path.expand("../../lib", __DIR__),
  Path.expand("../../priv/static/assets", __DIR__)
]

config :tailwind, clarity_config[:tailwind]
