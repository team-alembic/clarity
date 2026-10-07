import Config

# Required since Ash 3.34 for the demo resources' string length constraints.
config :ash, default_string_length_count: :codepoints

config :demo, DemoWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  http: [ip: {127, 0, 0, 1}, port: System.get_env("PORT", "4000")],
  secret_key_base: "Hu4qQN3iKzTV4fJxhorPQlA/osH9fAMtbtjVS58PFgfw3ja5Z18Q/WSNR9wP4OfW",
  live_view: [signing_salt: "hMegieSe"],
  pubsub_server: Demo.PubSub,
  check_origin: false

config :demo,
  ash_domains: [
    Demo.Accounts,
    Demo.Projects,
    Demo.Helpdesk,
    Demo.Billing
  ]

config :mdex_native, syntax_highlighter: :lumis

config :phoenix, :json_library, Jason

if config_env() == :dev, do: import_config("dev.exs")
