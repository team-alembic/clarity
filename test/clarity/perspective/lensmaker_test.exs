defmodule Clarity.Perspective.LensmakerTest do
  use ExUnit.Case, async: true

  import Phoenix.Component

  alias Clarity.Perspective.Lens
  alias Clarity.Perspective.Lensmaker
  alias Clarity.Vertex.Ash.Policy
  alias Clarity.Vertex.Ash.Resource
  alias Clarity.Vertex.Phoenix.Router

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
        filter: true
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
        filter: false
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
        filter: true
      }
    end
  end

  describe "get_all_lenses/1" do
    test "discovers lensmakers and creates lenses using current app config" do
      lenses = Lensmaker.get_all_lenses()
      assert is_list(lenses)
    end

    test "creates lenses from explicit lensmaker list" do
      lensmakers = [TestLensmaker1, TestLensmaker2]

      lenses = Lensmaker.get_all_lenses(lensmakers)
      assert length(lenses) == 2

      lens1 = Enum.find(lenses, &(&1.id == "test1"))
      lens2 = Enum.find(lenses, &(&1.id == "test2"))

      assert %Lens{name: "Test Lens 1"} = lens1
      assert %Lens{name: "Test Lens 2"} = lens2
    end

    test "skips lensmakers that don't implement make_lens/0" do
      lensmakers = [TestLensmaker1, UpdateOnlyLensmaker]

      lenses = Lensmaker.get_all_lenses(lensmakers)
      assert length(lenses) == 1

      assert %Lens{id: "test1", name: "Test Lens 1"} = List.first(lenses)
    end

    test "works with lensmakers that only implement make_lens/0" do
      lensmakers = [MakeOnlyLensmaker]

      lenses = Lensmaker.get_all_lenses(lensmakers)
      assert length(lenses) == 1

      assert %Lens{id: "make_only", name: "Make Only Lens"} = List.first(lenses)
    end

    test "handles empty lensmaker list" do
      assert [] = Lensmaker.get_all_lenses([])
    end

    test "applies update_lens/1 from other lensmakers" do
      lensmakers = [TestLensmaker1, UpdateOnlyLensmaker]

      lenses = Lensmaker.get_all_lenses(lensmakers)
      assert length(lenses) == 1

      lens = List.first(lenses)
      assert %Lens{id: "test1", description: "Enhanced by TestEnhancer"} = lens
    end

    defmodule AnotherUpdater do
      @moduledoc false
      @behaviour Lensmaker

      @impl Lensmaker
      def update_lens(%{id: "test1"} = lens) do
        %{lens | description: "Updated by AnotherUpdater"}
      end

      def update_lens(lens), do: lens
    end

    test "multiple lensmakers can update the same lens" do
      lensmakers = [TestLensmaker1, UpdateOnlyLensmaker, AnotherUpdater]

      lenses = Lensmaker.get_all_lenses(lensmakers)
      assert length(lenses) == 1

      lens = List.first(lenses)

      assert %Lens{
               id: "test1",
               description: "Updated by AnotherUpdater"
             } = lens
    end

    defmodule InvalidLensmaker do
      @moduledoc false
    end

    test "handles invalid lensmaker modules gracefully" do
      assert [] = Lensmaker.get_all_lenses([InvalidLensmaker])
    end

    test "crashes for invalid arguments" do
      assert_raise Protocol.UndefinedError, fn ->
        Lensmaker.get_all_lenses(:not_a_list)
      end
    end
  end

  describe "get_lens_by_id/1" do
    test "finds lens by ID from discovered lenses" do
      assert {:ok, %Lens{id: "debug", name: "Debug"}} = Lensmaker.get_lens_by_id("debug")
    end

    test "returns error for unknown lens ID" do
      assert {:error, :lens_not_found} = Lensmaker.get_lens_by_id("unknown_lens")
    end
  end

  describe "lensmaker show_vertex_types" do
    test "debug lens shows all types" do
      {:ok, debug_lens} = Lensmaker.get_lens_by_id("debug")

      types = [
        Clarity.Vertex.Application,
        Clarity.Vertex.Module,
        Clarity.Vertex.Root
      ]

      shown_types = debug_lens.show_vertex_types.(types)

      assert shown_types == types
    end

    test "architect lens shows only architectural types" do
      {:ok, architect_lens} = Lensmaker.get_lens_by_id("architect")

      types = [
        Clarity.Vertex.Application,
        Clarity.Vertex.Module,
        Resource,
        Router
      ]

      shown_types = architect_lens.show_vertex_types.(types)

      assert Clarity.Vertex.Application in shown_types
      refute Clarity.Vertex.Module in shown_types
      assert Resource in shown_types
      assert Router in shown_types
    end

    test "security lens shows only security-related types" do
      {:ok, security_lens} = Lensmaker.get_lens_by_id("security")

      types = [
        Clarity.Vertex.Application,
        Clarity.Vertex.Module,
        Policy,
        Router
      ]

      shown_types = security_lens.show_vertex_types.(types)

      assert Clarity.Vertex.Application in shown_types
      refute Clarity.Vertex.Module in shown_types
      assert Policy in shown_types
      assert Router in shown_types
    end
  end
end
