defmodule AshAtlas.Layouts do
  @moduledoc false

  use AshAtlas.Web, :html
  use Phoenix.Component

  js_path = Path.join(__DIR__, "../../../priv/static/assets/app.js")
  css_path = Path.join(__DIR__, "../../../priv/static/assets/app.css")

  @external_resource js_path
  @external_resource css_path

  @app_js File.read!(js_path)
  @app_css File.read!(css_path)

  def render("app.js", _), do: @app_js
  def render("app.css", _), do: @app_css

  def render("root.html", assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en" phx-socket={live_socket_path(@conn)}>
      <head>
        <meta charset="utf-8" />
        <meta http-equiv="X-UA-Compatible" content="IE=edge" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0, minimum-scale=1.0" />
        <meta name="csrf-token" content={get_csrf_token()} />
        <title>{assigns[:page_title] || "Ash Atlas"}</title>
        <style nonce={csp_nonce(@conn, :style)}>
          <%= raw(render("app.css", %{})) %>
        </style>
      </head>
      <body>
        {@inner_content}
      </body>
      <script nonce={csp_nonce(@conn, :script)}>
        <%= raw(render("app.js", %{})) %>
      </script>
    </html>
    """
  end

  def render("app.html", assigns) do
    ~H"""
    {@inner_content}
    """
  end

  def render(assigns) do
    ~H"""
    ...
    """
  end

  def live_socket_path(conn) do
    [Enum.map(conn.script_name, &["/" | &1]) | conn.private.live_socket_path]
  end

  defp csp_nonce(conn, type) when type in [:script, :style, :img] do
    csp_nonce_value = conn.private.ash_atlas_csp_nonce[type]

    case csp_nonce_value do
      key when is_atom(key) -> conn.assigns[csp_nonce_value]
      key when is_bitstring(key) -> csp_nonce_value
      _ -> raise("Unexpected type of :csp_nonce_assign_key")
    end
  end
end
