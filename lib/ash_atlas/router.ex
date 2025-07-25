defmodule AshAtlas.Router do
  @moduledoc """
  Router for the AshAtlas LiveView application.
  """

  @doc """
  Can be used to create a `:browser` pipeline easily if you don't have one.

  By default it is called `:browser`, but you can rename it by supplying an
  argument, for example:

  ```elixir
  defmodule MyAppWeb.Router do
    use Phoenix.Router

    import AshAtlas.Router
    atlas_browser_pipeline :something

    scope "/" do
      pipe_through [:something]
      ash_atlas "/atlas"
    end
  end
  ```
  """
  defmacro atlas_browser_pipeline(name \\ :browser) do
    quote do
      import Phoenix.LiveView.Router

      pipeline unquote(name) do
        plug(:accepts, ["html"])
        plug(:fetch_session)
        plug(:fetch_live_flash)
        plug(:put_root_layout, html: {AshAtlas.Layouts, :root})
        plug(:protect_from_forgery)
        plug(:put_secure_browser_headers)
      end
    end
  end

  @doc """
  Defines an `ash_atlas` route.
  It expects the `path` the atlas dashboard will be mounted at
  and a set of options.

  ## Options

    * `:live_socket_path` - Optional override for the socket path. it must match
      the `socket "/live", Phoenix.LiveView.Socket` in your endpoint. Defaults to `/live`.

    * `:on_mount` - Optional list of hooks to attach to the mount lifecycle.

    * `:session` - Optional extra session map or MFA tuple to be merged with the session.

    * `:csp_nonce_assign_key` - Optional assign key to find the CSP nonce value used for assets
      Supports either `atom()` or
        `%{optional(:img) => atom(), optional(:script) => atom(), optional(:style) => atom()}`
        Defaults to `ash_atlas-Ed55GFnX` for backwards compatibility.

    * `:live_session_name` - Optional atom to name the `live_session`. Defaults to `:ash_atlas`.

  ## Examples

  ```elixir
  defmodule MyAppWeb.Router do
    use Phoenix.Router

    scope "/" do
      import AshAtlas.Router

      # Make sure you are piping through the browser pipeline
      # If you don't have one, see `atlas_browser_pipeline/1`
      pipe_through [:browser]

      ash_atlas "/atlas"
      ash_atlas "/csp/atlas", live_session_name: :ash_atlas_csp, csp_nonce_assign_key: :csp_nonce_value
    end
  end
  ```
  """
  defmacro ash_atlas(path, opts \\ []) do
    quote bind_quoted: [path: path, opts: opts] do
      import Phoenix.LiveView.Router

      live_socket_path = Keyword.get(opts, :live_socket_path, "/live")

      csp_nonce_assign_key =
        case opts[:csp_nonce_assign_key] do
          nil ->
            %{
              img: "ash_atlas-Ed55GFnX",
              style: "ash_atlas-Ed55GFnX",
              script: "ash_atlas-Ed55GFnX"
            }

          key when is_atom(key) ->
            %{img: key, style: key, script: key}

          %{} = keys ->
            Map.take(keys, [:img, :style, :script])
        end

      # TODO: Remove internal API usage
      full_path = "/" <> String.trim(Enum.join(@phoenix_top_scopes.path, "/") <> path, "/")

      live_session opts[:live_session_name] || :ash_atlas,
        on_mount: List.wrap(opts[:on_mount]),
        session:
          {AshAtlas.Router, :__session__, [%{"prefix" => full_path}, List.wrap(opts[:session])]},
        root_layout: {AshAtlas.Layouts, :root} do
        live(
          "#{path}",
          AshAtlas.PageLive,
          :page,
          private: %{
            live_socket_path: live_socket_path,
            ash_atlas_csp_nonce: csp_nonce_assign_key
          }
        )

        live(
          "#{path}/:vertex/:content",
          AshAtlas.PageLive,
          :page,
          private: %{
            live_socket_path: live_socket_path,
            ash_atlas_csp_nonce: csp_nonce_assign_key
          }
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
