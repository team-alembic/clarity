# Worker and telemetry tests wait on background processes that can take
# several hundred milliseconds to reply when the machine is busy (e.g. under
# `mix check`, alongside dialyzer). assert_receive returns as soon as the
# message arrives, so a generous ceiling only slows down genuine failures.
ExUnit.start(capture_log: true, exclude: [:slow], assert_receive_timeout: 2_000)

# The demo app's code is compiled into the test build for its domains and
# routes, but its endpoint config lives in `demo/config`, not ours. Here its
# modules belong to `:clarity`, which LiveViewTest resolves static paths from.
Application.put_env(:demo, DemoWeb.Endpoint,
  otp_app: :clarity,
  url: [host: "localhost"],
  secret_key_base: "Hu4qQN3iKzTV4fJxhorPQlA/osH9fAMtbtjVS58PFgfw3ja5Z18Q/WSNR9wP4OfW",
  live_view: [signing_salt: "hMegieSe"],
  pubsub_server: Demo.PubSub
)

{:ok, _pid} = Supervisor.start_link([DemoWeb.Endpoint], strategy: :one_for_one)
