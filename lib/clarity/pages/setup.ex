defmodule Clarity.Pages.Setup do
  @moduledoc false

  import Phoenix.Component
  import Phoenix.LiveView

  alias Phoenix.LiveView.Socket

  @doc false
  @spec on_mount(
          arg :: term(),
          params :: Phoenix.LiveView.unsigned_params() | :not_mounted_at_router,
          session :: map(),
          socket :: Socket.t()
        ) :: {:cont, Socket.t()} | {:halt, Socket.t()}
  @engines ~w(dot neato fdp sfdp circo twopi osage patchwork)
  @default_engine "dot"

  def on_mount(_name, _params, %{"prefix" => prefix} = session, socket) do
    connect_params = get_connect_params(socket) || %{}

    theme =
      case connect_params["theme"] do
        "dark" -> :dark
        "light" -> :light
        _ -> :light
      end

    engine =
      case connect_params["engine"] do
        engine when engine in @engines -> engine
        _ -> @default_engine
      end

    socket =
      socket
      |> assign(
        prefix: prefix,
        theme: theme,
        engine: engine,
        clarity_pid: Map.get(session, "clarity_pid", Clarity.Server)
      )
      |> attach_hook(:theme_handler, :handle_event, &handle_theme_event/3)
      |> attach_hook(:engine_handler, :handle_event, &handle_engine_event/3)

    {:cont, socket}
  end

  @spec handle_theme_event(event :: String.t(), params :: map(), socket :: Socket.t()) ::
          {:cont, Socket.t()} | {:halt, Socket.t()}
  defp handle_theme_event("set-theme", %{"theme" => theme_string}, socket)
       when theme_string in ["dark", "light"] do
    theme = String.to_existing_atom(theme_string)
    {:halt, assign(socket, theme: theme)}
  end

  defp handle_theme_event(_event, _params, socket) do
    {:cont, socket}
  end

  @spec handle_engine_event(event :: String.t(), params :: map(), socket :: Socket.t()) ::
          {:cont, Socket.t()} | {:halt, Socket.t()}
  defp handle_engine_event("set-engine", %{"engine" => engine}, socket) when engine in @engines do
    {:halt,
     socket
     |> assign(engine: engine)
     |> push_event("clarity:engine-changed", %{engine: engine})}
  end

  defp handle_engine_event(_event, _params, socket) do
    {:cont, socket}
  end
end
