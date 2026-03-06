defmodule Clarity.Graph.StateRef do
  @moduledoc false

  alias Clarity.Graph.Backend

  @spec new(Backend.state()) :: :ets.tid()
  def new(backend_state) do
    ref = :ets.new(:graph_state, [:set, :public])
    :ets.insert(ref, {:state, backend_state})
    ref
  end

  @spec get(:ets.tid()) :: Backend.state()
  def get(ref) do
    :ets.lookup_element(ref, :state, 2)
  end

  @spec put(:ets.tid(), Backend.state()) :: true
  def put(ref, backend_state) do
    :ets.insert(ref, {:state, backend_state})
  end

  @spec give_away(:ets.tid(), pid()) :: true
  def give_away(ref, pid) do
    :ets.give_away(ref, pid, :graph_handover)
  end

  @spec delete(:ets.tid()) :: true
  def delete(ref) do
    :ets.delete(ref)
  end
end
