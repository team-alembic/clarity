defmodule Clarity.Server.QueueTest do
  use ExUnit.Case, async: true

  alias Clarity.Server.Queue
  alias Clarity.Server.Task
  alias Clarity.Vertex

  @spec task(module(), Queue.lane()) :: Task.t()
  defp task(name, lane) do
    %Task{id: make_ref(), lane: lane, vertex: %Vertex.Module{module: name}}
  end

  @spec drain(Queue.t()) :: [module()]
  defp drain(queue) do
    case Queue.pop(queue) do
      :empty -> []
      {:ok, task, rest} -> [task.vertex.module | drain(rest)]
    end
  end

  describe inspect(&Queue.lanes/0) do
    test "lists the lanes in the order they run" do
      assert Queue.lanes() == [:model, :modules, :dependencies]
    end
  end

  describe inspect(&Queue.earlier/2) do
    test "returns the earlier lane" do
      assert Queue.earlier(:model, :dependencies) == :model
      assert Queue.earlier(:dependencies, :modules) == :modules
      assert Queue.earlier(:modules, :modules) == :modules
    end
  end

  describe inspect(&Queue.pop/1) do
    test "is empty for a new queue" do
      assert Queue.pop(Queue.new()) == :empty
    end

    test "takes tasks first in first out within a lane" do
      queue = Enum.reduce([A, B, C], Queue.new(), &Queue.push(&2, task(&1, :modules)))

      assert drain(queue) == [A, B, C]
    end

    test "takes tasks of earlier lanes first" do
      queue =
        Queue.new()
        |> Queue.push(task(Dep, :dependencies))
        |> Queue.push(task(Mod, :modules))
        |> Queue.push(task(Model, :model))

      assert drain(queue) == [Model, Mod, Dep]
    end
  end

  describe inspect(&Queue.push/2) do
    test "puts a task in its lane" do
      queue = Queue.push(Queue.new(), task(A, :modules))

      assert Queue.size(queue, [:modules]) == 1
      assert Queue.size(queue, [:model]) == 0
    end
  end

  describe inspect(&Queue.size/2) do
    test "counts tasks as they come and go" do
      queue =
        Queue.new()
        |> Queue.push(task(A, :model))
        |> Queue.push(task(B, :modules))
        |> Queue.push(task(C, :dependencies))

      assert Queue.size(queue) == 3
      assert Queue.size(queue, [:model, :modules]) == 2

      {:ok, _task, queue} = Queue.pop(queue)

      assert Queue.size(queue) == 2
      assert Queue.size(queue, [:model]) == 0
    end
  end

  describe inspect(&Queue.promote/3) do
    setup do
      queue =
        Queue.new()
        |> Queue.push(task(Model, :model))
        |> Queue.push(task(ModA, :modules))
        |> Queue.push(task(ModB, :modules))
        |> Queue.push(task(DepA, :dependencies))
        |> Queue.push(task(DepB, :dependencies))

      %{queue: queue}
    end

    test "moves picked tasks from later lanes to the back of the lane", %{queue: queue} do
      queue = Queue.promote(queue, :model, &(&1.vertex.module in [DepB, ModB]))

      assert Queue.size(queue, [:model]) == 3
      assert Queue.size(queue, [:modules]) == 1
      assert Queue.size(queue, [:dependencies]) == 1
      assert Enum.take(drain(queue), 3) == [Model, ModB, DepB]
    end

    test "sets the lane of promoted tasks", %{queue: queue} do
      queue = Queue.promote(queue, :modules, &(&1.vertex.module == DepA))
      {:ok, _model, queue} = Queue.pop(queue)
      {:ok, _first, queue} = Queue.pop(queue)
      {:ok, _second, queue} = Queue.pop(queue)

      assert {:ok, %Task{lane: :modules, vertex: %{module: DepA}}, _queue} = Queue.pop(queue)
    end

    test "leaves earlier lanes alone", %{queue: queue} do
      queue = Queue.promote(queue, :dependencies, fn _task -> true end)

      assert Queue.size(queue, [:model]) == 1
      assert Queue.size(queue, [:modules]) == 2
      assert drain(queue) == [Model, ModA, ModB, DepA, DepB]
    end

    test "keeps the order of what it leaves", %{queue: queue} do
      queue = Queue.promote(queue, :model, &(&1.vertex.module == ModA))

      assert drain(queue) == [Model, ModA, ModB, DepA, DepB]
    end
  end
end
