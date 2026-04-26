defmodule Clarity.Content.C4.ContainersTest do
  use ExUnit.Case, async: true

  alias Clarity.Content.C4.Containers
  alias Clarity.Vertex.Application
  alias Clarity.Vertex.Root

  test "name + sort priority" do
    assert Containers.name() == "C4 — Containers"
    assert Containers.sort_priority() == -96
  end

  describe inspect(&Containers.applies?/2) do
    test "applies only to the :clarity Application vertex" do
      assert Containers.applies?(%Application{app: :clarity, description: nil, version: "0.4.0"}, nil)
      refute Containers.applies?(%Application{app: :kernel, description: nil, version: "10.0"}, nil)
      refute Containers.applies?(%Root{}, nil)
    end
  end

  describe inspect(&Containers.render_static/2) do
    test "returns a D2 diagram with Clarity boundary, internal containers and external systems" do
      vertex = %Application{app: :clarity, description: nil, version: "0.4.0"}
      {:d2, render_fn} = Containers.render_static(vertex, nil)
      d2 = IO.iodata_to_binary(render_fn.(%{theme: :light, zoom_subgraph: nil}))

      # Containers in scope
      for container <- ["Browser SPA", "PageLive", "Clarity.Server", "Worker Pool", "Graph", "Cache"] do
        assert d2 =~ container, "expected the C4 container diagram to mention #{container}"
      end

      # Element types tagged in markdown labels
      assert d2 =~ "[Container:"
      assert d2 =~ "[Person]"
      assert d2 =~ "[Software System]"

      # Data stores rendered as cylinders per C4 convention
      assert d2 =~ "shape: cylinder"

      # Dashed boundary for the system in scope
      assert d2 =~ "stroke-dash"

      # Diagram MUST include a key
      assert d2 =~ "### Key"
    end
  end
end
