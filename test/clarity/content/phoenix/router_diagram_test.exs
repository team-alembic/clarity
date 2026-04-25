defmodule Clarity.Content.Phoenix.RouterDiagramTest do
  use ExUnit.Case, async: true

  alias Clarity.Content.Phoenix.RouterDiagram
  alias Clarity.Vertex.Phoenix.Router
  alias Clarity.Vertex.Root

  describe inspect(&RouterDiagram.applies?/2) do
    test "true for Phoenix Router vertex" do
      assert RouterDiagram.applies?(%Router{router: DemoWeb.Router}, nil)
    end

    test "false for non-router vertex" do
      refute RouterDiagram.applies?(%Root{}, nil)
    end
  end

  describe inspect(&RouterDiagram.render_static/2) do
    test "renders one container per HTTP verb with route nodes" do
      d2 = render(DemoWeb.Router)

      assert d2 =~ "direction: down"
      assert d2 =~ "shape: package"
      assert d2 =~ "shape: rectangle"
    end
  end

  @spec render(module()) :: String.t()
  defp render(router) do
    {:d2, render_fn} = RouterDiagram.render_static(%Router{router: router}, nil)
    IO.iodata_to_binary(render_fn.(%{theme: :light, zoom_subgraph: nil}))
  end
end
