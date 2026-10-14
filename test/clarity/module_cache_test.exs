defmodule Clarity.ModuleCacheTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Clarity.ModuleCache
  alias Clarity.ModuleCacheTest.Changing

  test "keeps a result while the code of the modules stays the same" do
    key = make_ref()

    assert ModuleCache.fetch(key, [Enum], fn -> 1 end) == 1
    assert ModuleCache.fetch(key, [Enum], fn -> 2 end) == 1
  end

  test "works the result out again when the code of a module changes" do
    key = make_ref()

    compile(1)
    assert ModuleCache.fetch(key, [Changing], fn -> 1 end) == 1

    compile(2)
    assert ModuleCache.fetch(key, [Changing], fn -> 2 end) == 2
  end

  @spec compile(integer()) :: String.t()
  defp compile(value) do
    capture_io(:stderr, fn ->
      Code.compile_string("defmodule #{inspect(Changing)}, do: def(value, do: #{value})")
    end)
  end
end
