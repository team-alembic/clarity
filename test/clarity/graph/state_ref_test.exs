defmodule Clarity.Graph.StateRefTest do
  use ExUnit.Case, async: true

  alias Clarity.Graph.StateRef

  test "new/1 creates a ref and get/1 retrieves the value" do
    ref = StateRef.new(:initial_state)
    assert StateRef.get(ref) == :initial_state
    StateRef.delete(ref)
  end

  test "put/2 updates the stored value" do
    ref = StateRef.new(:first)
    assert StateRef.get(ref) == :first

    StateRef.put(ref, :second)
    assert StateRef.get(ref) == :second
    StateRef.delete(ref)
  end

  test "give_away/2 transfers ownership to another process" do
    ref = StateRef.new(:test_state)

    task =
      Task.async(fn ->
        receive do
          {:"ETS-TRANSFER", _ref, _pid, :graph_handover} -> :ok
        after
          1000 -> :timeout
        end
      end)

    StateRef.give_away(ref, task.pid)
    assert Task.await(task) == :ok
  end

  test "delete/1 removes the ETS table" do
    ref = StateRef.new(:disposable)
    assert StateRef.get(ref) == :disposable

    StateRef.delete(ref)

    assert_raise ArgumentError, fn ->
      StateRef.get(ref)
    end
  end
end
