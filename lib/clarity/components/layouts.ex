defmodule Clarity.Layouts do
  @moduledoc false

  use Clarity.Web, :html

  embed_templates "layouts/*"

  @spec live_socket_path(Plug.Conn.t()) :: iodata()
  defp live_socket_path(conn) do
    [Enum.map(conn.script_name, &["/" | &1]) | conn.private.live_socket_path]
  end

  # Where the page loads `entry` from (see Clarity.Assets).
  @spec asset_path(Plug.Conn.t(), String.t()) :: String.t()
  defp asset_path(conn, entry) do
    conn.script_name
    |> Enum.map_join(&["/" | &1])
    |> Kernel.<>(conn.private.clarity_prefix)
    |> Clarity.Assets.path(entry)
  end
end
