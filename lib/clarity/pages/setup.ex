defmodule Clarity.Pages.Setup do
  @moduledoc false

  import Phoenix.Component
  import Phoenix.LiveView

  alias Clarity.Report.Actions
  alias Phoenix.LiveView.AsyncResult
  alias Phoenix.LiveView.Socket

  @doc false
  @spec on_mount(
          arg :: term(),
          params :: Phoenix.LiveView.unsigned_params() | :not_mounted_at_router,
          session :: map(),
          socket :: Socket.t()
        ) :: {:cont, Socket.t()} | {:halt, Socket.t()}
  def on_mount(_name, _params, %{"prefix" => prefix} = session, socket) do
    params = get_connect_params(socket) || %{}

    theme =
      case params["theme"] do
        "dark" -> :dark
        "light" -> :light
        _ -> :light
      end

    socket =
      socket
      |> assign(
        prefix: prefix,
        theme: theme,
        linking: linking(params["linking"]),
        # Short unless the viewer chose names in full.
        name_style: if(params["name_style"] == "qualified", do: :qualified, else: :short),
        clarity_pid: Map.get(session, "clarity_pid", Clarity.Server)
      )
      |> attach_hook(:settings_handler, :handle_event, &handle_settings_event/3)
      |> assign_action_tallies()
      |> attach_hook(:action_tallies, :handle_info, &handle_work_completed/2)

    {:cont, socket}
  end

  # Every page's activity bar counts the things to do the reports find. The
  # counting runs off the page (some reports' actions take a while), and runs
  # again when introspection finishes; Clarity.Report.Actions caches it per
  # change to the graph, so pages share the work.
  @spec assign_action_tallies(Socket.t()) :: Socket.t()
  defp assign_action_tallies(socket) do
    if connected?(socket) do
      clarity_pid = socket.assigns.clarity_pid

      assign_async(socket, :action_tallies, fn ->
        graph = Clarity.get(clarity_pid, :partial).graph
        {:ok, %{action_tallies: Actions.tallies(graph)}}
      end)
    else
      assign(socket, :action_tallies, AsyncResult.loading())
    end
  end

  @spec handle_work_completed(term(), Socket.t()) :: {:cont, Socket.t()}
  defp handle_work_completed({:clarity, :work_completed}, socket),
    do: {:cont, assign_action_tallies(socket)}

  defp handle_work_completed(_message, socket), do: {:cont, socket}

  @spec handle_settings_event(event :: String.t(), params :: map(), socket :: Socket.t()) ::
          {:cont, Socket.t()} | {:halt, Socket.t()}
  defp handle_settings_event("set-theme", %{"theme" => theme_string}, socket)
       when theme_string in ["dark", "light"] do
    theme = String.to_existing_atom(theme_string)
    {:halt, assign(socket, theme: theme)}
  end

  defp handle_settings_event("set-name-style", %{"style" => style}, socket)
       when style in ["short", "qualified"] do
    {:halt, assign(socket, name_style: String.to_existing_atom(style))}
  end

  defp handle_settings_event("set-linking", %{} = changes, socket) do
    {:halt, assign(socket, linking: linking(changes, socket.assigns.linking))}
  end

  defp handle_settings_event(_event, _params, socket) do
    {:cont, socket}
  end

  # The viewer's text linking options, as the settings menu sends them, over
  # `linking`: lowercase names link unless turned off, every mention only if
  # turned on.
  @spec linking(term(), Clarity.Autolink.options()) :: Clarity.Autolink.options()
  defp linking(settings, linking \\ [every: false, lowercase: true])

  defp linking(%{} = settings, linking) do
    Enum.reduce(linking, linking, fn {option, _enabled}, linking ->
      case Map.get(settings, Atom.to_string(option)) do
        enabled when is_boolean(enabled) -> Keyword.put(linking, option, enabled)
        _unset -> linking
      end
    end)
  end

  defp linking(_settings, linking), do: linking
end
