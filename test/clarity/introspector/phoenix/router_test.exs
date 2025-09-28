defmodule Clarity.Introspector.Phoenix.RouterTest do
  use ExUnit.Case, async: true

  alias Clarity.Introspector.Phoenix.Router, as: RouterIntrospector
  alias Clarity.Vertex
  alias Clarity.Vertex.Phoenix.Router
  alias Clarity.Vertex.Root

  describe inspect(&RouterIntrospector.introspect_vertex/2) do
    test "creates router vertex for Phoenix router modules" do
      graph = Clarity.Graph.new()

      clarity_app_vertex = %Vertex.Application{app: :clarity, description: "Clarity App", version: "1.0.0"}
      Clarity.Graph.add_vertex(graph, clarity_app_vertex, %Root{})

      module_vertex = %Vertex.Module{module: DemoWeb.Router}

      assert {:ok,
              [
                {:vertex, %Router{router: DemoWeb.Router}},
                {:edge, ^module_vertex, %Router{router: DemoWeb.Router}, "router"},
                {:edge, ^clarity_app_vertex, %Router{router: DemoWeb.Router}, "router"}
                | _
              ]} = RouterIntrospector.introspect_vertex(module_vertex, graph)
    end

    test "returns empty list for non-router modules" do
      graph = Clarity.Graph.new()
      module_vertex = %Vertex.Module{module: String}

      assert {:ok, []} = RouterIntrospector.introspect_vertex(module_vertex, graph)
    end
  end
end
