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
  @engines ~w(dot neato fdp sfdp circo twopi osage)
  @default_engine "dot"
  @d2_layouts ~w(dagre elk)
  @default_d2_layout "dagre"
  @name_styles ~w(qualified short)
  @default_name_style "qualified"

  def on_mount(_name, _params, %{"prefix" => prefix} = session, socket) do
    connect_params = get_connect_params(socket) || %{}

    socket =
      socket
      |> assign(
        prefix: prefix,
        theme: resolve_theme(connect_params["theme"]),
        engine: resolve_engine(connect_params["engine"]),
        d2_layout: resolve_d2_layout(connect_params["d2_layout"]),
        name_style: resolve_name_style(connect_params["name_style"]),
        clarity_pid: Map.get(session, "clarity_pid", Clarity.Server)
      )
      |> attach_hook(:theme_handler, :handle_event, &handle_theme_event/3)
      |> attach_hook(:engine_handler, :handle_event, &handle_engine_event/3)
      |> attach_hook(:d2_layout_handler, :handle_event, &handle_d2_layout_event/3)
      |> attach_hook(:name_style_handler, :handle_event, &handle_name_style_event/3)

    {:cont, socket}
  end

  @spec resolve_theme(term()) :: :light | :dark
  defp resolve_theme("dark"), do: :dark
  defp resolve_theme(_), do: :light

  @spec resolve_engine(term()) :: String.t()
  defp resolve_engine(value) when value in @engines, do: value
  defp resolve_engine(_), do: @default_engine

  @spec resolve_d2_layout(term()) :: String.t()
  defp resolve_d2_layout(value) when value in @d2_layouts, do: value
  defp resolve_d2_layout(_), do: @default_d2_layout

  @spec resolve_name_style(term()) :: :qualified | :short
  defp resolve_name_style(value) when value in @name_styles, do: String.to_existing_atom(value)

  defp resolve_name_style(_), do: String.to_existing_atom(@default_name_style)

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

  @spec handle_d2_layout_event(event :: String.t(), params :: map(), socket :: Socket.t()) ::
          {:cont, Socket.t()} | {:halt, Socket.t()}
  defp handle_d2_layout_event("set-d2-layout", %{"layout" => layout}, socket)
       when layout in @d2_layouts do
    {:halt,
     socket
     |> assign(d2_layout: layout)
     |> push_event("clarity:d2-layout-changed", %{layout: layout})}
  end

  defp handle_d2_layout_event(_event, _params, socket) do
    {:cont, socket}
  end

  @spec handle_name_style_event(event :: String.t(), params :: map(), socket :: Socket.t()) ::
          {:cont, Socket.t()} | {:halt, Socket.t()}
  defp handle_name_style_event("set-name-style", %{"style" => style}, socket)
       when style in @name_styles do
    style_atom = String.to_existing_atom(style)

    {:halt,
     socket
     |> assign(name_style: style_atom)
     |> push_event("clarity:name-style-changed", %{style: style})}
  end

  defp handle_name_style_event(_event, _params, socket) do
    {:cont, socket}
  end
end
