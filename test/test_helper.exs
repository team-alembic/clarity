# Worker and telemetry tests wait on background processes that can take
# several hundred milliseconds to reply when the machine is busy (e.g. under
# `mix check`, alongside dialyzer). assert_receive returns as soon as the
# message arrives, so a generous ceiling only slows down genuine failures.
ExUnit.start(capture_log: true, exclude: [:slow], assert_receive_timeout: 2_000)
