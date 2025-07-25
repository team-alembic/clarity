defmodule AshAtlas.Web do
  @moduledoc false

  @spec static_paths :: [Path.t()]
  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  @spec router :: Macro.t()
  def router do
    quote do
      use Phoenix.Router, helpers: false

      import Phoenix.Controller
      import Phoenix.LiveView.Router

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
    end
  end

  @spec channel :: Macro.t()
  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  @spec live_view :: Macro.t()
  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {AshAtlas.Layouts, :app}

      unquote(html_helpers())
    end
  end

  @spec live_component :: Macro.t()
  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  @spec html :: Macro.t()
  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  @spec html_helpers() :: Macro.t()
  defp html_helpers do
    quote do
      # use Gettext, backend: AshAtlas.Gettext

      import AshAtlas.CoreComponents

      # HTML escaping functionality
      import Phoenix.HTML
      # Core UI components and translation

      # Shortcut for generating JS commands
      alias Phoenix.LiveView.JS

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  @spec verified_routes() :: Macro.t()
  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        router: AshAtlas.Router,
        statics: AshAtlas.Web.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
