defmodule Clarity.Content.Ash.ApplicationDiagramFlowTest do
  use ExUnit.Case, async: true

  alias Clarity.Content.Ash.ApplicationDiagramFlow
  alias Clarity.Vertex.Application
  alias Clarity.Vertex.Root

  describe inspect(&ApplicationDiagramFlow.name/0) do
    test "returns name with Flow suffix" do
      assert ApplicationDiagramFlow.name() == "Application Diagram (Flow)"
    end
  end

  describe inspect(&ApplicationDiagramFlow.sort_priority/0) do
    test "sorts after the D2 variant" do
      assert ApplicationDiagramFlow.sort_priority() == -80
    end
  end

  describe inspect(&ApplicationDiagramFlow.applies?/2) do
    test "true for Application vertex with Ash domains" do
      vertex = %Application{app: :clarity, description: nil, version: "0.4.0"}
      assert ApplicationDiagramFlow.applies?(vertex, nil)
    end

    test "false for Application vertex without Ash domains" do
      vertex = %Application{app: :kernel, description: nil, version: "10.1"}
      refute ApplicationDiagramFlow.applies?(vertex, nil)
    end

    test "false for non-Application vertices" do
      refute ApplicationDiagramFlow.applies?(%Root{}, nil)
    end
  end

  describe inspect(&ApplicationDiagramFlow.render_static/2) do
    test "returns live_flow tuple with function" do
      vertex = %Application{app: :clarity, description: nil, version: "0.4.0"}
      assert {:live_flow, render_fn} = ApplicationDiagramFlow.render_static(vertex, nil)
      assert is_function(render_fn, 1)
    end

    test "produces a flow definition with the expected shape" do
      flow = render(:light)

      assert is_list(flow.nodes)
      assert flow.edges == []
      assert is_map(flow.opts)
      assert flow.opts.controls == true
      assert flow.opts.background == :dots
      assert flow.opts.fit_view_on_init == true
      assert flow.opts.snap_to_grid == true
      assert flow.opts.nodes_connectable == false

      assert is_map(flow.node_types)
      assert is_function(Map.fetch!(flow.node_types, :resource), 1)
    end

    test "emits one LiveFlow.Node per Ash resource with vertex_id and palette" do
      flow = render(:light)

      assert Enum.all?(flow.nodes, fn node ->
               match?(%LiveFlow.Node{type: :resource, connectable: false}, node)
             end)

      labels = Enum.map(flow.nodes, & &1.data.label)
      assert "User" in labels

      user_node = Enum.find(flow.nodes, fn node -> node.data.label == "User" end)
      assert user_node.data.vertex_id == "ash-resource:demo-accounts-user"
      assert user_node.data.fill == "#fef3c7"
    end

    test "dark theme swaps the fill palette" do
      light = render(:light)
      dark = render(:dark)

      light_user = Enum.find(light.nodes, &(&1.data.label == "User"))
      dark_user = Enum.find(dark.nodes, &(&1.data.label == "User"))

      assert light_user.data.fill == "#fef3c7"
      assert dark_user.data.fill == "#854d0e"
    end

    test "lays out resources in a domain-grouped grid (column = resource within domain)" do
      flow = render(:light)
      same_domain = Enum.filter(flow.nodes, &(&1.data.domain == "Demo.Accounts"))

      ys = same_domain |> Enum.map(& &1.position.y) |> Enum.uniq()
      assert length(ys) == 1, "all resources in one domain should share a row"

      xs = Enum.map(same_domain, & &1.position.x)
      assert xs == Enum.sort(xs), "x positions should be monotonically increasing"
    end
  end

  @spec render(:light | :dark) :: map()
  defp render(theme) do
    vertex = %Application{app: :clarity, description: nil, version: "0.4.0"}
    {:live_flow, render_fn} = ApplicationDiagramFlow.render_static(vertex, nil)
    render_fn.(%{theme: theme, zoom_subgraph: nil})
  end
end
