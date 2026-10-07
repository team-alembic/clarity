import Config

# Clarity is developed alongside this app, so rebuild its assets with the
# profiles from its own config and reload its code as well as the demo's.
clarity_config = Config.Reader.read!(Path.expand("../../config/config.exs", __DIR__), env: :dev)

# Those profiles build into Clarity's priv/static/assets, the assets it ships.
# Build into a gitignored directory instead, and have Clarity embed from there,
# so the shipped assets only change on a deliberate `mix assets.deploy`.
dev_assets = Path.expand("../../tmp/dev_assets", __DIR__)

build_into_dev_assets = fn profiles ->
  update_in(profiles, [:default, :args], fn args ->
    Enum.map(args, fn
      "--outdir=" <> _ -> "--outdir=#{dev_assets}"
      "--output=" <> path -> "--output=#{Path.join(dev_assets, Path.basename(path))}"
      arg -> arg
    end)
  end)
end

config :clarity, :assets_path, dev_assets

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
      ~r"tmp/dev_assets/.*(js|css)$",
      ~r"lib/clarity/(pages|components)/.*(ex)$",
      ~r"lib/demo_web/.*(ex)$"
    ]
  ]

config :esbuild, build_into_dev_assets.(clarity_config[:esbuild])

config :phoenix, :plug_init_mode, :runtime
config :phoenix, :stacktrace_depth, 20

config :phoenix_live_reload, :dirs, [
  "",
  Path.expand("../../lib", __DIR__),
  dev_assets
]

config :tailwind, build_into_dev_assets.(clarity_config[:tailwind])
