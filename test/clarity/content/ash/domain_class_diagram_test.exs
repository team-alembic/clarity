defmodule Clarity.Content.Ash.DomainClassDiagramTest do
  use ExUnit.Case, async: true

  alias Clarity.Content.Ash.DomainClassDiagram
  alias Clarity.Vertex.Ash.Domain
  alias Clarity.Vertex.Root

  describe inspect(&DomainClassDiagram.applies?/2) do
    test "true for a Domain vertex with resources" do
      assert DomainClassDiagram.applies?(%Domain{domain: Demo.Accounts}, nil)
    end

    test "false for non-domain vertices" do
      refute DomainClassDiagram.applies?(%Root{}, nil)
    end
  end

  describe inspect(&DomainClassDiagram.render_static/2) do
    test "renders class shapes for every resource in the domain" do
      d2 = render(Demo.Accounts)

      assert d2 =~ "direction: right"
      assert d2 =~ "shape: class"
      assert d2 =~ ~s|"User"|
    end
  end

  @spec render(module()) :: String.t()
  defp render(domain) do
    {:d2, render_fn} = DomainClassDiagram.render_static(%Domain{domain: domain}, nil)
    IO.iodata_to_binary(render_fn.(%{theme: :light, zoom_subgraph: nil}))
  end
end
