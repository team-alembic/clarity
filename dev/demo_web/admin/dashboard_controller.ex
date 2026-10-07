defmodule DemoWeb.Admin.DashboardController do
  @moduledoc "Internal admin views. Stubbed."

  use Phoenix.Controller, formats: [:html]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params), do: send_resp(conn, 200, "Admin dashboard")

  @spec audit_log(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def audit_log(conn, _params), do: send_resp(conn, 200, "Audit log")
end
