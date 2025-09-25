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

  @doc false
  @spec start_link(opts :: GenServer.options()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    opts = Keyword.put_new(opts, :name, __MODULE__)

    GenServer.start_link(__MODULE__, [], opts)
  end

  @impl GenServer
  def init(_opts), do: {:ok, nil}

  @impl GenServer
  def handle_info({:modules_compiled, _listener_update}, state) do
    case GenServer.whereis(Clarity) do
      nil -> :clarity_not_running
      # TODO: Implement incremental updates
      _pid -> Clarity.start_link()
    end

    {:noreply, state}
  end

  def handle_info({:dep_compiled, _listener_update}, state) do
    case GenServer.whereis(Clarity) do
      nil -> :clarity_not_running
      # TODO: Implement incremental updates
      _pid -> Clarity.start_link()
    end

    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}
end
