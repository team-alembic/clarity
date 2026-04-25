defmodule Clarity.Content.Ash.ApplicationDiagramD2Test do
  use ExUnit.Case, async: true

  alias Clarity.Content.Ash.ApplicationDiagramD2
  alias Clarity.Vertex.Application
  alias Clarity.Vertex.Root

  describe inspect(&ApplicationDiagramD2.name/0) do
    test "returns name with D2 suffix" do
      assert ApplicationDiagramD2.name() == "Application Diagram (D2)"
    end
  end

  describe inspect(&ApplicationDiagramD2.applies?/2) do
    test "true for Application vertex with Ash domains" do
      vertex = %Application{app: :clarity, description: nil, version: "0.4.0"}
      assert ApplicationDiagramD2.applies?(vertex, nil)
    end

    test "false for Application vertex without Ash domains" do
      vertex = %Application{app: :kernel, description: nil, version: "10.1"}
      refute ApplicationDiagramD2.applies?(vertex, nil)
    end

    test "false for non-Application vertices" do
      refute ApplicationDiagramD2.applies?(%Root{}, nil)
    end
  end

  describe inspect(&ApplicationDiagramD2.render_static/2) do
    test "returns d2 tuple with function" do
      vertex = %Application{app: :clarity, description: nil, version: "0.4.0"}
      assert {:d2, render_fn} = ApplicationDiagramD2.render_static(vertex, nil)
      assert is_function(render_fn, 1)
    end

    test "rendered D2 source contains domain container and resource node" do
      d2 = render(:light)

      assert d2 =~ "direction: down"
      assert d2 =~ "shape: package"
      assert d2 =~ "shape: rectangle"
      assert d2 =~ "Demo_Accounts:"
      assert d2 =~ ~s|"User"|
      assert d2 =~ ~s|link: "vertex://ash-resource:demo-accounts-user"|
    end

    test "dark theme uses dark palette colours" do
      light = render(:light)
      dark = render(:dark)

      refute light == dark
      assert light =~ "#fef3c7"
      assert dark =~ "#854d0e"
    end
  end

  @spec render(:light | :dark) :: String.t()
  defp render(theme) do
    vertex = %Application{app: :clarity, description: nil, version: "0.4.0"}
    {:d2, render_fn} = ApplicationDiagramD2.render_static(vertex, nil)
    IO.iodata_to_binary(render_fn.(%{theme: theme, zoom_subgraph: nil}))
  end
end
