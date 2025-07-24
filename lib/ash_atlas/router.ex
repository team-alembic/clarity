defmodule AshAtlas.Router do
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

      live_session opts[:live_session_name] || :ash_atlas,
        on_mount: List.wrap(opts[:on_mount]),
        session:
          {AshAtlas.Router, :__session__, [%{"prefix" => path}, List.wrap(opts[:session])]},
        root_layout: {AshAtlas.Layouts, :root} do

        live(
          "#{path}",
          AshAtlas.PageLive,
          :page,
          private: %{
            # base_path
            live_socket_path: live_socket_path,
            ash_atlas_csp_nonce: csp_nonce_assign_key
          }
        )

        live(
          "#{path}/:node/:content",
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
  def __session__(conn, [session, additional_hooks]),
    do: __session__(conn, session, additional_hooks)

  def __session__(conn, session, additional_hooks \\ []) do
    session =
      Enum.reduce(additional_hooks, session, fn {m, f, a}, acc ->
        Map.merge(acc, apply(m, f, [conn | a]) || %{})
      end)

    session = Map.put(session, "request_path", conn.request_path)

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
