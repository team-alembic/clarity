defmodule DemoWeb.Router do
  @moduledoc false

  use Phoenix.Router

  pipeline :browser do
    plug :fetch_session
    plug :fetch_query_params
  end

  scope "/" do
    import Clarity.Router

    pipe_through :browser
    clarity("/")
  end
end
