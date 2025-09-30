defmodule Clarity.Perspective.RegistryTest do
  use ExUnit.Case, async: true

  import Phoenix.Component

  alias Clarity.Graph.Filter
  alias Clarity.Perspective.Lens
  alias Clarity.Perspective.Lensmaker
  alias Clarity.Perspective.Registry
  alias Clarity.Vertex.Root

  defmodule TestLensmaker1 do
    @moduledoc false
    @behaviour Lensmaker

    @impl Lensmaker
    def make_lens do
      %Lens{
        id: "test1",
        name: "Test Lens 1",
        icon: fn ->
          assigns = %{}
          ~H"🧪"
        end,
        filter: Filter.custom(fn _vertex -> true end),
        intro_vertex: fn _graph -> %Root{} end
      }
    end

    @impl Lensmaker
    def update_lens(lens), do: lens
  end

  defmodule TestLensmaker2 do
    @moduledoc false
    @behaviour Lensmaker

    @impl Lensmaker
    def make_lens do
      %Lens{
        id: "test2",
        name: "Test Lens 2",
        icon: fn ->
          assigns = %{}
          ~H"⚡"
        end,
        filter: Filter.custom(fn _vertex -> false end),
        intro_vertex: fn _graph -> nil end
      }
    end

    @impl Lensmaker
    def update_lens(lens), do: lens
  end

  defmodule UpdateOnlyLensmaker do
    @moduledoc false
    @behaviour Lensmaker

    @impl Lensmaker
    def update_lens(%{id: "test1"} = lens) do
      %{lens | description: "Enhanced by TestEnhancer"}
    end

    def update_lens(lens), do: lens
  end

  defmodule MakeOnlyLensmaker do
    @moduledoc false
    @behaviour Lensmaker

    @impl Lensmaker
    def make_lens do
      %Lens{
        id: "make_only",
        name: "Make Only Lens",
        icon: fn ->
          assigns = %{}
          ~H"⚙️"
        end,
        filter: Filter.custom(fn _vertex -> true end),
        intro_vertex: fn _graph -> %Root{} end
      }
    end
  end

  describe "discover_lensmakers/0" do
    test "returns list from current application environment" do
      # This tests the real discovery mechanism with the current app
      lensmakers = Registry.discover_lensmakers()
      assert is_list(lensmakers)
      # Don't assert specific content since it depends on the current environment
    end
  end

  describe "get_all_lenses/1" do
    test "discovers lensmakers and creates lenses using current app config" do
      lenses = Registry.get_all_lenses()
      assert is_list(lenses)
    end

    test "creates lenses from explicit lensmaker list" do
      lensmakers = [TestLensmaker1, TestLensmaker2]

      lenses = Registry.get_all_lenses(lensmakers)
      assert length(lenses) == 2

      lens1 = Enum.find(lenses, &(&1.id == "test1"))
      lens2 = Enum.find(lenses, &(&1.id == "test2"))

      assert %Lens{name: "Test Lens 1"} = lens1
      assert %Lens{name: "Test Lens 2"} = lens2
    end

    test "skips lensmakers that don't implement make_lens/0" do
      lensmakers = [TestLensmaker1, UpdateOnlyLensmaker]

      lenses = Registry.get_all_lenses(lensmakers)
      assert length(lenses) == 1

      assert %Lens{id: "test1", name: "Test Lens 1"} = List.first(lenses)
    end

    test "works with lensmakers that only implement make_lens/0" do
      lensmakers = [MakeOnlyLensmaker]

      lenses = Registry.get_all_lenses(lensmakers)
      assert length(lenses) == 1

      assert %Lens{id: "make_only", name: "Make Only Lens"} = List.first(lenses)
    end

    test "handles empty lensmaker list" do
      assert [] = Registry.get_all_lenses([])
    end

    test "applies update_lens/1 from other lensmakers" do
      lensmakers = [TestLensmaker1, UpdateOnlyLensmaker]

      lenses = Registry.get_all_lenses(lensmakers)
      assert length(lenses) == 1

      lens = List.first(lenses)
      assert %Lens{id: "test1", description: "Enhanced by TestEnhancer"} = lens
    end

    test "multiple lensmakers can update the same lens" do
      defmodule AnotherUpdater do
        @moduledoc false
        @behaviour Lensmaker

        @impl Lensmaker
        def update_lens(%{id: "test1"} = lens) do
          %{lens | description: "Updated by AnotherUpdater"}
        end

        def update_lens(lens), do: lens
      end

      lensmakers = [TestLensmaker1, UpdateOnlyLensmaker, AnotherUpdater]

      lenses = Registry.get_all_lenses(lensmakers)
      assert length(lenses) == 1

      lens = List.first(lenses)

      assert %Lens{
               id: "test1",
               description: "Updated by AnotherUpdater"
             } = lens
    end

    test "handles invalid lensmaker modules gracefully" do
      defmodule InvalidLensmaker do
        @moduledoc false
      end

      assert [] = Registry.get_all_lenses([InvalidLensmaker])
    end

    test "crashes for invalid arguments" do
      # Since we removed defensive programming, this should crash with Protocol.UndefinedError
      assert_raise Protocol.UndefinedError, fn ->
        Registry.get_all_lenses(:not_a_list)
      end
    end
  end

  describe "get_lens_by_id/1" do
    test "finds lens by ID from discovered lenses" do
      assert {:ok, %Lens{id: "debug", name: "Debug"}} = Registry.get_lens_by_id("debug")
    end

    test "returns error for unknown lens ID" do
      assert {:error, :lens_not_found} = Registry.get_lens_by_id("unknown_lens")
    end
  end
end
