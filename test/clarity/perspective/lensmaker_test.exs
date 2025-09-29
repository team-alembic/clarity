defmodule Clarity.Perspective.LensmakerTest do
  use ExUnit.Case, async: true

  import Phoenix.Component

  alias Clarity.Graph.Filter
  alias Clarity.Perspective.Lens
  alias Clarity.Perspective.Lensmaker
  alias Clarity.Vertex.Root

  defmodule TestLensmaker do
    @moduledoc false
    @behaviour Lensmaker

    @impl Lensmaker
    def make_lens do
      %Lens{
        id: "test",
        name: "Test Lens",
        description: "Test lens for testing",
        icon: fn ->
          assigns = %{}
          ~H"🧪"
        end,
        filter: Filter.custom(fn _vertex -> true end),
        intro_vertex: fn _graph -> %Root{} end
      }
    end

    @impl Lensmaker
    def update_lens(lens) do
      assert %Lens{} = lens

      %{lens | description: "Updated by TestLensmaker"}
    end
  end

  defmodule UpdateOnlyLensmaker do
    @moduledoc false
    @behaviour Lensmaker

    @impl Lensmaker
    def update_lens(%{id: "test"} = lens) do
      %{lens | description: "Updated by UpdateOnlyLensmaker"}
    end

    def update_lens(lens), do: lens
  end

  describe "behavior callbacks" do
    test "make_lens/0 callback creates a lens" do
      assert %Lens{
               id: "test",
               name: "Test Lens",
               description: "Test lens for testing"
             } = TestLensmaker.make_lens()
    end

    test "update_lens/1 callback modifies existing lens" do
      lens = %Lens{
        id: "existing",
        name: "Existing",
        icon: fn ->
          assigns = %{}
          ~H"⚡"
        end,
        filter: Filter.custom(fn _vertex -> false end),
        intro_vertex: fn _graph -> nil end
      }

      updated_lens = TestLensmaker.update_lens(lens)
      assert "Updated by TestLensmaker" = updated_lens.description
    end

    test "update_lens/1 can be selective based on lens id" do
      test_lens = %Lens{
        id: "test",
        name: "Test",
        description: "Original description",
        icon: fn ->
          assigns = %{}
          ~H"🧪"
        end,
        filter: Filter.custom(fn _vertex -> true end),
        intro_vertex: fn _graph -> %Root{} end
      }

      other_lens = %Lens{
        id: "other",
        name: "Other",
        description: "Other description",
        icon: fn ->
          assigns = %{}
          ~H"🔍"
        end,
        filter: Filter.custom(fn _vertex -> true end),
        intro_vertex: fn _graph -> %Root{} end
      }

      updated_test = UpdateOnlyLensmaker.update_lens(test_lens)
      assert "Updated by UpdateOnlyLensmaker" = updated_test.description

      unchanged_other = UpdateOnlyLensmaker.update_lens(other_lens)
      assert "Other description" = unchanged_other.description
    end

    test "lensmaker without make_lens/1 can still update lenses" do
      lens = %Lens{
        id: "test",
        name: "Test",
        description: "Original",
        icon: fn ->
          assigns = %{}
          ~H"🧪"
        end,
        filter: Filter.custom(fn _vertex -> true end),
        intro_vertex: fn _graph -> %Root{} end
      }

      updated = UpdateOnlyLensmaker.update_lens(lens)
      assert "Updated by UpdateOnlyLensmaker" = updated.description
    end
  end
end
