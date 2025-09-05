defmodule Atlas.Layouts do
  @moduledoc false

  use Atlas.Web, :html
  use Phoenix.Component

  embed_templates "layouts/*"

  @spec live_socket_path(Plug.Conn.t()) :: iodata()
  defp live_socket_path(conn) do
    [Enum.map(conn.script_name, &["/" | &1]) | conn.private.live_socket_path]
  end
end
