defmodule Clarity.Perspective.Lensmaker.GraphNavigationTest do
  use ExUnit.Case, async: true

  alias Clarity.Content
  alias Clarity.Perspective.Lens
  alias Clarity.Perspective.Lensmaker.GraphNavigation
  alias Phoenix.LiveView.Rendered

  describe "make_lens/0" do
    test "shows only the graph, without framework internals" do
      assert %Lens{id: "graph", name: "Graph", contents: [Content.Graph], show_internals?: false} =
               lens = GraphNavigation.make_lens()

      assert is_function(lens.filter, 1)
    end

    test "has an icon" do
      assert %Rendered{} = GraphNavigation.make_lens().icon.()
    end
  end
end
