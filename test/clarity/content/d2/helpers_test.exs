defmodule Clarity.Content.D2.HelpersTest do
  use ExUnit.Case, async: true

  alias Clarity.Content.D2.Helpers
  alias Clarity.Vertex.Root

  describe inspect(&Helpers.safe_id/1) do
    test "replaces unsafe characters with underscore" do
      assert Helpers.safe_id("Foo.Bar.Baz") == "Foo_Bar_Baz"
      assert Helpers.safe_id("a-b c") == "a_b_c"
    end
  end

  describe inspect(&Helpers.short_name/1) do
    test "returns the last segment of a module name" do
      assert Helpers.short_name(Foo.Bar.Baz) == "Baz"
    end
  end

  describe inspect(&Helpers.quoted/1) do
    test "wraps in quotes and escapes embedded quotes and backslashes" do
      assert IO.iodata_to_binary(Helpers.quoted(~s|hello "world"|)) == ~S|"hello \"world\""|
      assert IO.iodata_to_binary(Helpers.quoted("a\\b")) == ~S|"a\\b"|
    end
  end

  describe inspect(&Helpers.domain_palette/2) do
    test "wraps around the palette length" do
      first = Helpers.domain_palette(0, :light)
      ninth = Helpers.domain_palette(8, :light)
      assert first == ninth
    end

    test "light and dark palettes return distinct colours" do
      refute Helpers.domain_palette(0, :light) == Helpers.domain_palette(0, :dark)
    end
  end

  describe inspect(&Helpers.neutral_palette/1) do
    test "returns three-tuple of strings for each theme" do
      assert {bg, fg, stroke} = Helpers.neutral_palette(:light)
      assert is_binary(bg) and is_binary(fg) and is_binary(stroke)

      assert {bg, fg, stroke} = Helpers.neutral_palette(:dark)
      assert is_binary(bg) and is_binary(fg) and is_binary(stroke)
    end
  end

  describe inspect(&Helpers.vertex_link/2) do
    test "produces a vertex:// URL using the Clarity vertex id" do
      result = Helpers.vertex_link(Root, [])
      assert IO.iodata_to_binary(result) == "vertex://" <> Clarity.Vertex.id(%Root{})
    end
  end
end
