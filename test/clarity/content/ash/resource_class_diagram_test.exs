defmodule Clarity.Content.Ash.ResourceClassDiagramTest do
  use ExUnit.Case, async: true

  alias Clarity.Content.Ash.ResourceClassDiagram
  alias Clarity.Vertex.Ash.Resource
  alias Clarity.Vertex.Root
  alias Demo.Accounts.User

  describe inspect(&ResourceClassDiagram.applies?/2) do
    test "true for any Ash resource" do
      assert ResourceClassDiagram.applies?(%Resource{resource: User}, nil)
    end

    test "false for non-resource vertices" do
      refute ResourceClassDiagram.applies?(%Root{}, nil)
    end
  end

  describe inspect(&ResourceClassDiagram.render_static/2) do
    test "renders class shape and links to vertex" do
      d2 = render(User)

      assert d2 =~ "shape: class"
      assert d2 =~ ~s|"User"|
      assert d2 =~ ~s|link: "vertex://ash-resource:demo-accounts-user"|
    end

    test "marks primary keys with asterisk and shows visibility prefix" do
      d2 = render(User)
      assert d2 =~ ~s|"* +id"| or d2 =~ ~s|"* -id"|
    end
  end

  @spec render(module()) :: String.t()
  defp render(resource) do
    {:d2, render_fn} = ResourceClassDiagram.render_static(%Resource{resource: resource}, nil)
    IO.iodata_to_binary(render_fn.(%{theme: :light, zoom_subgraph: nil}))
  end
end
