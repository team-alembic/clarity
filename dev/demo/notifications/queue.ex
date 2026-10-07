defmodule Demo.Notifications.Queue do
  @moduledoc """
  In-memory FIFO buffer for notifications that have not yet been
  dispatched. The demo never drains it; it exists for the Supervision
  Tree diagram to have a sibling worker.
  """

  use GenServer

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @spec enqueue(term()) :: :ok
  def enqueue(message), do: GenServer.cast(__MODULE__, {:enqueue, message})

  @spec size() :: non_neg_integer()
  def size, do: GenServer.call(__MODULE__, :size)

  @impl GenServer
  def init(_opts), do: {:ok, :queue.new()}

  @impl GenServer
  def handle_cast({:enqueue, message}, queue), do: {:noreply, :queue.in(message, queue)}

  @impl GenServer
  def handle_call(:size, _from, queue), do: {:reply, :queue.len(queue), queue}
end
