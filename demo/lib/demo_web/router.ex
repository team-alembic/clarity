defmodule DemoWeb.Router do
  @moduledoc false

  use Phoenix.Router

  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :fetch_session
    plug :fetch_query_params
    plug :put_secure_browser_headers
    plug :accepts, ["html"]
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_query_params
  end

  pipeline :admin do
    plug :fetch_session
    plug :fetch_query_params
    plug :accepts, ["html"]
  end

  scope "/marketing" do
    pipe_through :browser

    get "/pricing", DemoWeb.PageController, :pricing
    get "/docs", DemoWeb.PageController, :docs
  end

  scope "/app" do
    pipe_through :browser

    live "/inbox", DemoWeb.InboxLive
    live "/board/:project_key", DemoWeb.BoardLive
  end

  scope "/api/v1", DemoWeb.API.V1 do
    pipe_through :api

    get "/projects", ProjectController, :index
    get "/projects/:id", ProjectController, :show
    post "/projects", ProjectController, :create
    patch "/projects/:id/archive", ProjectController, :archive

    get "/tickets", TicketController, :index
    get "/tickets/:id", TicketController, :show
    post "/tickets", TicketController, :create
    put "/tickets/:id", TicketController, :update
    patch "/tickets/:id", TicketController, :update
    delete "/tickets/:id", TicketController, :delete
    post "/tickets/:id/close", TicketController, :close
    post "/tickets/:id/reassign", TicketController, :reassign

    get "/billing/invoices", BillingController, :invoices
    get "/billing/subscription", BillingController, :subscription
    post "/billing/invoices/:id/mark_paid", BillingController, :mark_paid
  end

  scope "/admin", DemoWeb.Admin do
    pipe_through :admin

    get "/", DashboardController, :index
    get "/audit", DashboardController, :audit_log
  end

  scope "/" do
    import Clarity.Router

    pipe_through :browser
    clarity("/")
  end
end
