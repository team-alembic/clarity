defmodule Clarity.Content.Ash.DomainErDiagramTest do
  use ExUnit.Case, async: true

  alias Clarity.Content.Ash.DomainErDiagram
  alias Clarity.Vertex.Ash.Domain
  alias Clarity.Vertex.Root

  describe inspect(&DomainErDiagram.applies?/2) do
    test "true for Domain vertex with resources" do
      assert DomainErDiagram.applies?(%Domain{domain: Demo.Accounts}, nil)
    end

    test "false for non-Domain vertex" do
      refute DomainErDiagram.applies?(%Root{}, nil)
    end
  end

  describe inspect(&DomainErDiagram.render_static/2) do
    test "renders sql_tables for every resource in the domain" do
      d2 = render(Demo.Accounts)

      assert d2 =~ "direction: right"
      assert d2 =~ "shape: sql_table"
      assert d2 =~ ~s|"User"|
    end
  end

  @spec render(module()) :: String.t()
  defp render(domain) do
    {:d2, render_fn} = DomainErDiagram.render_static(%Domain{domain: domain}, nil)
    IO.iodata_to_binary(render_fn.(%{theme: :light, zoom_subgraph: nil}))
  end
end
