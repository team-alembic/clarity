defmodule DemoWeb.API.V1.ProjectController do
  @moduledoc "Project REST endpoints for the v1 API. Stubbed."

  use Phoenix.Controller, formats: [:json]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params), do: json(conn, %{projects: []})

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}), do: json(conn, %{id: id})

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, _params), do: conn |> put_status(:created) |> json(%{id: "stub"})

  @spec archive(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def archive(conn, _params), do: json(conn, %{archived: true})
end
