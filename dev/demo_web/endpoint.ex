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
