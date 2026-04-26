defmodule Clarity.Content.Ash.PolicyDiagramTest do
  use ExUnit.Case, async: true

  alias Clarity.Content.Ash.PolicyDiagram
  alias Clarity.Vertex.Ash.Resource
  alias Clarity.Vertex.Root
  alias Demo.Accounts.User

  describe inspect(&PolicyDiagram.applies?/2) do
    test "true for resources using Ash.Policy.Authorizer with policies" do
      assert PolicyDiagram.applies?(%Resource{resource: User}, nil)
    end

    test "false for non-resource vertices" do
      refute PolicyDiagram.applies?(%Root{}, nil)
    end
  end

  describe inspect(&PolicyDiagram.render_static/2) do
    test "rendered D2 source contains terminal nodes and at least one policy block" do
      {:d2, render_fn} =
        PolicyDiagram.render_static(%Resource{resource: User}, nil)

      d2 = %{theme: :light, zoom_subgraph: nil} |> render_fn.() |> IO.iodata_to_binary()

      assert d2 =~ ~s|"Request"|
      assert d2 =~ ~s|"Allow"|
      assert d2 =~ ~s|"Forbid"|
      assert d2 =~ "policy_0"
    end
  end
end
