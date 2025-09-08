defmodule DemoWeb.Router do
  use Phoenix.Router

  pipeline :browser do
    plug :fetch_session
    plug :fetch_query_params
  end

  scope "/" do
    import Atlas.Router

    pipe_through :browser
    atlas("/")
  end
end
