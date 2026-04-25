defmodule Demo.Notifications.Dispatcher do
  @moduledoc """
  Fans buffered notifications out to subscriber processes registered in
  `Demo.Notifications.Registry`. Pure stub for the demo — it accepts
  `dispatch/1` casts and counts them.
  """

  use GenServer

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @spec dispatch(term()) :: :ok
  def dispatch(message), do: GenServer.cast(__MODULE__, {:dispatch, message})

  @spec count() :: non_neg_integer()
  def count, do: GenServer.call(__MODULE__, :count)

  @impl GenServer
  def init(_opts), do: {:ok, %{count: 0}}

  @impl GenServer
  def handle_cast({:dispatch, _message}, state),
    do: {:noreply, %{state | count: state.count + 1}}

  @impl GenServer
  def handle_call(:count, _from, state), do: {:reply, state.count, state}
end
