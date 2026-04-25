defmodule Clarity.Content.Ash.ResourceErDiagramTest do
  use ExUnit.Case, async: true

  alias Clarity.Content.Ash.ResourceErDiagram
  alias Clarity.Vertex.Ash.Resource
  alias Clarity.Vertex.Root
  alias Demo.Accounts.User

  describe inspect(&ResourceErDiagram.applies?/2) do
    test "true for Ash resource vertex" do
      assert ResourceErDiagram.applies?(%Resource{resource: User}, nil)
    end

    test "false for non-resource vertices" do
      refute ResourceErDiagram.applies?(%Root{}, nil)
    end
  end

  describe inspect(&ResourceErDiagram.render_static/2) do
    test "returns d2 tuple with function" do
      assert {:d2, render_fn} =
               ResourceErDiagram.render_static(%Resource{resource: User}, nil)

      assert is_function(render_fn, 1)
    end

    test "renders sql_table for the focused resource" do
      d2 = render(User)

      assert d2 =~ "shape: sql_table"
      assert d2 =~ ~s|"User"|
      assert d2 =~ "stroke-width: 3"
      assert d2 =~ ~s|link: "vertex://ash-resource:demo-accounts-user"|
    end

    test "marks primary key attributes with a leading asterisk" do
      d2 = render(User)
      assert d2 =~ ~s|"* id"|
    end
  end

  @spec render(module()) :: String.t()
  defp render(resource) do
    {:d2, render_fn} = ResourceErDiagram.render_static(%Resource{resource: resource}, nil)
    IO.iodata_to_binary(render_fn.(%{theme: :light, zoom_subgraph: nil}))
  end
end
