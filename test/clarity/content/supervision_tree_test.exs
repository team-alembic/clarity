defmodule Clarity.Content.SupervisionTreeTest do
  use ExUnit.Case, async: true

  alias Clarity.Content.SupervisionTree
  alias Clarity.Vertex.Application
  alias Clarity.Vertex.Root

  describe inspect(&SupervisionTree.applies?/2) do
    test "true for an OTP application that is currently running" do
      vertex = %Application{app: :clarity, description: nil, version: "0.4.0"}
      assert SupervisionTree.applies?(vertex, nil)
    end

    test "false for an Application vertex of an app that is not started" do
      vertex = %Application{app: :nonexistent_app, description: nil, version: "0.0.0"}
      refute SupervisionTree.applies?(vertex, nil)
    end

    test "false for non-application vertices" do
      refute SupervisionTree.applies?(%Root{}, nil)
    end
  end

  describe inspect(&SupervisionTree.render_static/2) do
    test "produces D2 source rooted at the app" do
      vertex = %Application{app: :clarity, description: nil, version: "0.4.0"}
      {:d2, render_fn} = SupervisionTree.render_static(vertex, nil)
      d2 = %{theme: :light, zoom_subgraph: nil} |> render_fn.() |> IO.iodata_to_binary()

      assert d2 =~ "direction: down"
      assert d2 =~ ~s|"clarity"|
    end
  end
end
