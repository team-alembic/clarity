defmodule Clarity.IconComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Clarity.IconComponents

  describe inspect(&IconComponents.vertex_icon_sprite/1) do
    test "defines a symbol for every icon a vertex hint can use" do
      document = LazyHTML.from_fragment(render_component(&IconComponents.vertex_icon_sprite/1, %{}))

      for icon <- Clarity.Tooltip.icons() do
        symbol = LazyHTML.query(document, "symbol#clarity-icon-#{icon}")
        assert Enum.count(symbol) == 1, "no symbol for #{inspect(icon)}"
        assert symbol |> LazyHTML.query("path") |> Enum.count() > 0
      end
    end
  end
end
