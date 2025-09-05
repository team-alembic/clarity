defmodule Atlas.Pages.Setup do
  @moduledoc false

  import Phoenix.Component

  alias Phoenix.LiveView.Socket

  @spec on_mount(
          arg :: term(),
          params :: Phoenix.LiveView.unsigned_params() | :not_mounted_at_router,
          session :: map(),
          socket :: Socket.t()
        ) :: {:cont, Socket.t()} | {:halt, Socket.t()}
  def on_mount(
        _name,
        _params,
        %{"prefix" => prefix, "asset_path" => asset_path} = _session,
        socket
      ) do
    {:cont, assign(socket, prefix: prefix, asset_path: asset_path)}
  end
end
