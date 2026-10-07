defmodule DemoWeb.API.V1.TicketController do
  @moduledoc """
  REST endpoints for Tickets in the v1 API. Stubbed; only present so the
  Router Map can render verb-grouped routes with controller targets.
  """

  use Phoenix.Controller, formats: [:json]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params), do: json(conn, %{tickets: []})

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}), do: json(conn, %{id: id})

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, _params), do: conn |> put_status(:created) |> json(%{id: "stub"})

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, _params), do: json(conn, %{updated: true})

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, _params), do: send_resp(conn, 204, "")

  @spec close(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def close(conn, _params), do: json(conn, %{status: :closed})

  @spec reassign(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def reassign(conn, _params), do: json(conn, %{reassigned: true})
end
