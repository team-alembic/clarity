defmodule AshAtlas.Layouts do
  @moduledoc false

  use AshAtlas.Web, :html
  use Phoenix.Component

  @type nonce_type() :: :script | :style | :img

  @spec render(template :: String.t(), assigns :: Phoenix.LiveView.Socket.assigns()) ::
          Phoenix.LiveView.Rendered.t()
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
          <%= raw(app_css()) %>
        </style>
      </head>
      <body>
        {@inner_content}
      </body>
      <script nonce={csp_nonce(@conn, :script)}>
        <%= raw(app_js()) %>
      </script>
    </html>
    """
  end

  def render("app.html", assigns) do
    ~H"""
    {@inner_content}
    """
  end

  @spec live_socket_path(Plug.Conn.t()) :: iodata()
  defp live_socket_path(conn) do
    [Enum.map(conn.script_name, &["/" | &1]) | conn.private.live_socket_path]
  end

  @spec csp_nonce(conn :: Plug.Conn.t(), type :: nonce_type()) :: String.t()
  defp csp_nonce(conn, type) when type in [:script, :style, :img] do
    csp_nonce_value = conn.private.ash_atlas_csp_nonce[type]

    case csp_nonce_value do
      key when is_atom(key) -> conn.assigns[csp_nonce_value]
      key when is_bitstring(key) -> csp_nonce_value
      _ -> raise("Unexpected type of :csp_nonce_assign_key")
    end
  end

  js_path = Path.join(__DIR__, "../../../priv/static/assets/app.js")
  @external_resource js_path
  @app_js File.read!(js_path)
  @spec app_js() :: String.t()
  defp app_js, do: @app_js

  css_path = Path.join(__DIR__, "../../../priv/static/assets/app.css")
  @external_resource css_path
  @app_css File.read!(css_path)
  @spec app_css() :: String.t()
  defp app_css, do: @app_css
end
