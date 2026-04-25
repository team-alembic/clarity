defmodule Clarity.Content.Spark.ExtensionDiagramTest do
  use ExUnit.Case, async: true

  alias Ash.Resource.Dsl
  alias Clarity.Content.Spark.ExtensionDiagram
  alias Clarity.Vertex.Root
  alias Clarity.Vertex.Spark.Extension

  describe inspect(&ExtensionDiagram.applies?/2) do
    test "true for Spark Extension that exports sections/0" do
      assert ExtensionDiagram.applies?(%Extension{extension: Dsl}, nil)
    end

    test "false for non-extension vertices" do
      refute ExtensionDiagram.applies?(%Root{}, nil)
    end
  end

  describe inspect(&ExtensionDiagram.render_static/2) do
    test "produces nested D2 packages for sections" do
      {:d2, render_fn} =
        ExtensionDiagram.render_static(%Extension{extension: Dsl}, nil)

      d2 = %{theme: :light, zoom_subgraph: nil} |> render_fn.() |> IO.iodata_to_binary()

      assert d2 =~ "direction: down"
      assert d2 =~ "shape: package"
    end
  end
end
