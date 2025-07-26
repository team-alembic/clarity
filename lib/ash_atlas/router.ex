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

    * `:asset_path` - Optional override for the asset path. It must match
      the path of the atlas `Plug.Static` in your endpoint. Defaults to the
      base url of atlas.

    * `:on_mount` - Optional list of hooks to attach to the mount lifecycle.

    * `:session` - Optional extra session map or MFA tuple to be merged with the session.

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
    end
  end
  ```
  """
  defmacro ash_atlas(path, opts \\ []) do
    quote bind_quoted: [path: path, opts: opts] do
      import Phoenix.LiveView.Router

      live_socket_path = Keyword.get(opts, :live_socket_path, "/live")

      # TODO: Remove internal API usage
      full_path = "/" <> String.trim(Enum.join(@phoenix_top_scopes.path, "/") <> path, "/")

      asset_path = Keyword.get(opts, :asset_path, full_path)

      live_session opts[:live_session_name] || :ash_atlas,
        on_mount: [AshAtlas.Pages.Setup | List.wrap(opts[:on_mount])],
        session:
          {AshAtlas.Router, :__session__,
           [
             %{"prefix" => full_path, "asset_path" => asset_path},
             List.wrap(opts[:session])
           ]},
        root_layout: {AshAtlas.Layouts, :root} do
        live(
          "#{path}",
          AshAtlas.PageLive,
          :page,
          private: %{live_socket_path: live_socket_path}
        )

        live(
          "#{path}/:vertex/:content",
          AshAtlas.PageLive,
          :page,
          private: %{live_socket_path: live_socket_path}
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

  @doc false
  @spec __asset_path__(base_path :: Path.t(), filename :: Path.t()) :: Path.t()
  def __asset_path__(base_path, filename)

  cache_static_manifest_path = Application.app_dir(:ash_atlas, "priv/static/cache_manifest.json")
  @external_resource cache_static_manifest_path
  if File.exists?(cache_static_manifest_path) do
    @cache_static_manifest cache_static_manifest_path
                           |> File.read!()
                           |> JSON.decode!()
                           |> Map.fetch!("latest")
    def __asset_path__(base_path, filename) do
      case Map.fetch(@cache_static_manifest, filename) do
        :error -> Path.join([base_path, filename])
        {:ok, hashed_filename} -> Path.join([base_path, hashed_filename])
      end
    end
  else
    def __asset_path__(base_path, filename) do
      Path.join([base_path, filename])
    end
  end
end
