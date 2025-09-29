defmodule Clarity.Router do
  @moduledoc """
  Router for the Clarity LiveView application.
  """

  @doc """
  Can be used to create a `:browser` pipeline easily if you don't have one.

  By default it is called `:browser`, but you can rename it by supplying an
  argument, for example:

  ```elixir
  defmodule MyAppWeb.Router do
    use Phoenix.Router

    import Clarity.Router
    clarity_browser_pipeline :something

    scope "/" do
      pipe_through [:something]
      clarity "/clarity"
    end
  end
  ```
  """
  defmacro clarity_browser_pipeline(name \\ :browser) do
    quote do
      import Phoenix.LiveView.Router

      pipeline unquote(name) do
        plug(:accepts, ["html"])
        plug(:fetch_session)
        plug(:fetch_live_flash)
        plug(:put_root_layout, html: {Clarity.Layouts, :root})
        plug(:protect_from_forgery)
        plug(:put_secure_browser_headers)
      end
    end
  end

  @doc """
  Defines an `clarity` route.
  It expects the `path` the clarity dashboard will be mounted at
  and a set of options.

  ## Options

    * `:live_socket_path` - Optional override for the socket path. it must match
      the `socket "/live", Phoenix.LiveView.Socket` in your endpoint. Defaults to `/live`.

    * `:on_mount` - Optional list of hooks to attach to the mount lifecycle.

    * `:session` - Optional extra session map or MFA tuple to be merged with the session.

    * `:live_session_name` - Optional atom to name the `live_session`. Defaults to `:clarity`.

  ## Examples

  ```elixir
  defmodule MyAppWeb.Router do
    use Phoenix.Router

    scope "/" do
      import Clarity.Router

      # Make sure you are piping through the browser pipeline
      # If you don't have one, see `clarity_browser_pipeline/1`
      pipe_through [:browser]

      clarity "/clarity"
    end
  end
  ```
  """
  defmacro clarity(path, opts \\ []) do
    quote bind_quoted: [path: path, opts: opts] do
      import Phoenix.LiveView.Router

      live_socket_path = Keyword.get(opts, :live_socket_path, "/live")
      full_path = Phoenix.Router.scoped_path(__MODULE__, path)

      live_session_name = opts[:live_session_name] || :clarity
      on_mount = [Clarity.Pages.Setup | List.wrap(opts[:on_mount])]

      session =
        {Clarity.Router, :__session__,
         [
           %{"prefix" => full_path},
           List.wrap(opts[:session])
         ]}

      private = %{live_socket_path: live_socket_path}

      live_session live_session_name,
        on_mount: on_mount,
        session: session,
        root_layout: {Clarity.Layouts, :root} do
        live(
          "#{path}",
          Clarity.PageLive,
          :root,
          private: private
        )

        live(
          "#{path}/:lens",
          Clarity.PageLive,
          :lens,
          private: private
        )

        live(
          "#{path}/:lens/:vertex",
          Clarity.PageLive,
          :vertex,
          private: private
        )

        live(
          "#{path}/:lens/:vertex/:content",
          Clarity.PageLive,
          :page,
          private: private
        )
      end
    end
  end

  @cookies_to_replicate [
    "tenant",
    "actor_resource",
    "actor_primary_key",
    "actor_action",
    "actor_domain",
    "actor_authorizing",
    "actor_paused"
  ]

  @doc false
  @spec __session__(conn :: Plug.Conn.t(), [map() | [{module(), atom(), [any()]}]]) :: map()
  def __session__(conn, [session, additional_hooks]),
    do: __session__(conn, session, additional_hooks)

  @spec __session__(
          conn :: Plug.Conn.t(),
          session :: map(),
          additional_hooks :: [{module(), atom(), [any()]}]
        ) :: map()
  def __session__(conn, session, additional_hooks \\ []) do
    session =
      Enum.reduce(additional_hooks, session, fn {m, f, a}, acc ->
        Map.merge(acc, apply(m, f, [conn | a]) || %{})
      end)

    Enum.reduce(@cookies_to_replicate, session, fn cookie, session ->
      case conn.req_cookies[cookie] do
        value when value in [nil, "", "null"] ->
          Map.put(session, cookie, nil)

        value ->
          Map.put(session, cookie, value)
      end
    end)
  end
end
