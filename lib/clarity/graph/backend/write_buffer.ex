defmodule Clarity.Graph.Backend.WriteBuffer do
  @moduledoc false

  @spec enqueue(struct(), [term()], non_neg_integer(), (struct(), [term()] -> any())) :: struct()
  def enqueue(state, statements, batch_size, flush_fun) do
    new_buffer = Enum.reverse(statements) ++ state.write_buffer

    if length(new_buffer) >= batch_size do
      flush(%{state | write_buffer: new_buffer}, flush_fun)
    else
      %{state | write_buffer: new_buffer}
    end
  end

  @spec flush(struct(), (struct(), [term()] -> any())) :: struct()
  def flush(%{write_buffer: []} = state, _flush_fun), do: state

  def flush(state, flush_fun) do
    _ = flush_fun.(state, Enum.reverse(state.write_buffer))
    %{state | write_buffer: []}
  end
end
