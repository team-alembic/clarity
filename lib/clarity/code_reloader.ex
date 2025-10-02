defmodule Clarity.CodeReloader do
  @moduledoc """
  Simple Elixir CodeReloader listener that restarts Clarity on code changes.

  To use it, add `Clarity.CodeReloader` to your `:listeners` in your `mix.exs`:

      def project do
        [
          # ...
          listeners: [Clarity.CodeReloader]
        ]
      end
  """

  use GenServer

  alias Clarity.Config

  @doc false
  @spec child_spec(GenServer.options()) :: Supervisor.child_spec()
  def child_spec(opts), do: super(opts)

  @doc false
  @spec start_link(opts :: GenServer.options()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    opts = Keyword.put_new(opts, :name, __MODULE__)

    GenServer.start_link(__MODULE__, [], opts)
  end

  @impl GenServer
  def init(_opts), do: {:ok, nil}

  @impl GenServer
  def handle_info({event, listener_update}, state)
      when event in [:modules_compiled, :dep_compiled] do
    case GenServer.whereis(Clarity.Server) do
      nil ->
        :clarity_not_running

      _pid ->
        {app, modules_diff} = extract_app_and_modules_diff(listener_update)

        if Config.should_process_app?(app) do
          Clarity.introspect(Clarity.Server, {:incremental, app, modules_diff})
        end
    end

    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # Event Format: https://hexdocs.pm/mix/Mix.Task.Compiler.html#module-listening-to-compilation
  @spec extract_app_and_modules_diff(map()) :: {Application.app(), Clarity.modules_diff()}
  defp extract_app_and_modules_diff(%{
         app: app,
         modules_diff: %{changed: changed, added: added, removed: removed}
       }) do
    modules_diff = %{changed: changed, added: added, removed: removed}
    {app, modules_diff}
  end
end
