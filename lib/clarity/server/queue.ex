defmodule Clarity.Server.Queue do
  @moduledoc false

  # The introspection tasks waiting to run, in lanes run in order: a task runs
  # once every lane before its own is empty.
  #
  # - `:model`: the project's applications and the vertices introspecting them
  #   finds (Ash domains, resources and the like), and whatever of the
  #   dependencies those need
  # - `:modules`: how the project's modules relate (behaviours, protocols)
  # - `:dependencies`: the rest of the dependencies, in the background
  #
  # Sizes are counted as tasks come and go: `:queue.len/1` walks the queue.

  alias Clarity.Server.Task

  @lanes [:model, :modules, :dependencies]

  @type lane() :: :model | :modules | :dependencies

  @type t() :: %__MODULE__{
          lanes: %{lane() => :queue.queue(Task.t())},
          sizes: %{lane() => non_neg_integer()}
        }

  @enforce_keys [:lanes, :sizes]
  defstruct [:lanes, :sizes]

  @spec new() :: t()
  def new,
    do: %__MODULE__{lanes: Map.new(@lanes, &{&1, :queue.new()}), sizes: Map.new(@lanes, &{&1, 0})}

  @doc """
  Adds `task` at the back of its lane.
  """
  @spec push(t(), Task.t()) :: t()
  def push(%__MODULE__{} = queue, %Task{lane: lane} = task) do
    %{
      queue
      | lanes: Map.update!(queue.lanes, lane, &:queue.in(task, &1)),
        sizes: Map.update!(queue.sizes, lane, &(&1 + 1))
    }
  end

  @doc """
  Takes the next task: the first of the first lane with any.
  """
  @spec pop(t()) :: {:ok, Task.t(), t()} | :empty
  def pop(%__MODULE__{} = queue) do
    case Enum.find(@lanes, &(queue.sizes[&1] > 0)) do
      nil ->
        :empty

      lane ->
        {{:value, task}, rest} = :queue.out(queue.lanes[lane])

        {:ok, task,
         %{
           queue
           | lanes: Map.put(queue.lanes, lane, rest),
             sizes: Map.update!(queue.sizes, lane, &(&1 - 1))
         }}
    end
  end

  @doc """
  Moves the tasks in lanes after `lane` that `fun` picks into `lane`, at its
  back.
  """
  @spec promote(t(), lane(), (Task.t() -> boolean())) :: t()
  def promote(%__MODULE__{} = queue, lane, fun) do
    later_lanes = @lanes |> Enum.drop_while(&(&1 != lane)) |> tl()

    Enum.reduce(later_lanes, queue, fn later_lane, queue ->
      {promoted, kept} = queue.lanes[later_lane] |> :queue.to_list() |> Enum.split_with(fun)

      Enum.reduce(
        promoted,
        %{
          queue
          | lanes: Map.put(queue.lanes, later_lane, :queue.from_list(kept)),
            sizes: Map.put(queue.sizes, later_lane, length(kept))
        },
        &push(&2, %{&1 | lane: lane})
      )
    end)
  end

  @doc """
  The number of tasks waiting, in all lanes or in `lanes`.
  """
  @spec size(t(), [lane()]) :: non_neg_integer()
  def size(%__MODULE__{} = queue, lanes \\ @lanes) do
    queue.sizes |> Map.take(lanes) |> Map.values() |> Enum.sum()
  end

  @doc """
  The lanes, in the order they run.
  """
  @spec lanes() :: [lane()]
  def lanes, do: @lanes

  @doc """
  The earlier of two lanes.
  """
  @spec earlier(lane(), lane()) :: lane()
  def earlier(a, b), do: if(index(a) <= index(b), do: a, else: b)

  @spec index(lane()) :: non_neg_integer()
  defp index(lane), do: Enum.find_index(@lanes, &(&1 == lane))
end
