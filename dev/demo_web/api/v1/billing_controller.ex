defmodule DemoWeb.API.V1.BillingController do
  @moduledoc "Billing REST endpoints. Stubbed for diagram demo."

  use Phoenix.Controller, formats: [:json]

  @spec invoices(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def invoices(conn, _params), do: json(conn, %{invoices: []})

  @spec subscription(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def subscription(conn, _params), do: json(conn, %{subscription: nil})

  @spec mark_paid(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def mark_paid(conn, _params), do: json(conn, %{paid: true})
end
