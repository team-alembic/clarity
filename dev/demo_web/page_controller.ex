defmodule DemoWeb.PageController do
  @moduledoc """
  Public marketing-style pages for the demo app. Stubbed; routes exist so
  the Router Map diagram has interesting GET routes to render.
  """

  use Phoenix.Controller, formats: [:html]

  @spec home(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def home(conn, _params), do: send_resp(conn, 200, "OrbitDesk demo home")

  @spec pricing(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def pricing(conn, _params), do: send_resp(conn, 200, "Pricing")

  @spec docs(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def docs(conn, _params), do: send_resp(conn, 200, "Docs")
end
