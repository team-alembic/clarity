defmodule Clarity.Content.C4.SystemContextTest do
  use ExUnit.Case, async: true

  alias Clarity.Content.C4.SystemContext
  alias Clarity.Vertex.Application
  alias Clarity.Vertex.Root

  test "name + sort priority" do
    assert SystemContext.name() == "C4 — System Context"
    assert SystemContext.sort_priority() == -97
  end

  describe inspect(&SystemContext.applies?/2) do
    test "applies only to the :clarity Application vertex" do
      assert SystemContext.applies?(%Application{app: :clarity, description: nil, version: "0.4.0"}, nil)
      refute SystemContext.applies?(%Application{app: :kernel, description: nil, version: "10.0"}, nil)
      refute SystemContext.applies?(%Root{}, nil)
    end
  end

  describe inspect(&SystemContext.render_static/2) do
    test "returns a D2 diagram describing Clarity, the developer and external systems" do
      vertex = %Application{app: :clarity, description: nil, version: "0.4.0"}
      {:d2, render_fn} = SystemContext.render_static(vertex, nil)
      d2 = IO.iodata_to_binary(render_fn.(%{theme: :light, zoom_subgraph: nil}))

      # Required C4 elements
      assert d2 =~ "title:"
      assert d2 =~ "System Context"
      assert d2 =~ "shape: c4-person"
      assert d2 =~ "[Person]"
      assert d2 =~ "[Software System]"

      # Clarity is the system in scope; host, editor, forge are external
      assert d2 =~ "## Clarity"
      assert d2 =~ "Host Phoenix Application"
      assert d2 =~ "Code Editor"
      assert d2 =~ "Source Forge"

      # Diagram MUST include a key per c4model.com guidance
      assert d2 =~ "### Key"
    end
  end
end
