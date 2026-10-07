import Config

config :esbuild,
  version: "0.28.2",
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

if config_env() == :test do
  # Required since Ash 3.34 for the demo resources' string length constraints.
  config :ash, default_string_length_count: :codepoints

  # No network in tests; the advisory/registry introspectors then settle to
  # empty immediately rather than waiting on a fetch that never runs.
  config :clarity, :advisories, enabled?: false

  config :clarity,
    ash_domains: [
      Demo.Accounts,
      Demo.Projects,
      Demo.Helpdesk,
      Demo.Billing
    ]

  config :clarity, auto_start?: false

  config :logger, level: :debug
end

if Mix.env() == :dev do
  config :git_ops,
    mix_project: Clarity.MixProject,
    github_handle_lookup?: true,
    repository_url: "https://github.com/team-alembic/clarity",
    manage_mix_version?: true,
    # Instructs the tool to manage your mix version in your `mix.exs` file
    # See below for more information
    manage_readme_version: "README.md",
    # Instructs the tool to manage the version in your README.md
    # Pass in `true` to use `"README.md"` or a string to customize
    version_tag_prefix: "v"
end
