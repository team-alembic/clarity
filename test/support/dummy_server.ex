defmodule Clarity.Test.DummyServer do
  @moduledoc """
  Delivers a static Clarity struct for testing purposes.
  """

  use GenServer

  @spec start_link(Clarity.t()) :: GenServer.on_start()
  def start_link(clarity) do
    GenServer.start_link(__MODULE__, clarity)
  end

  @impl GenServer
  def init(clarity) do
    {:ok, clarity}
  end

  @impl GenServer
  def handle_call(:get, _from, clarity) do
    {:reply, clarity, clarity}
  end

  def handle_call({:put_graph, graph}, _from, clarity) do
    {:reply, :ok, %{clarity | graph: graph}}
  end

  def handle_call(:subscribe, _from, clarity) do
    # Return a dummy unsubscribe function for testing
    unsubscribe = fn -> :ok end
    {:reply, unsubscribe, clarity}
  end

  # Sent by :ets.give_away/3 when the test hands the graph over.
  @impl GenServer
  def handle_info({:"ETS-TRANSFER", _table, _from, :graph_handover}, clarity) do
    {:noreply, clarity}
  end
end
