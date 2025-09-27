defmodule Clarity.Introspector.Phoenix.EndpointTest do
  use ExUnit.Case, async: true

  alias Clarity.Introspector.Phoenix.Endpoint, as: EndpointIntrospector
  alias Clarity.Vertex
  alias Clarity.Vertex.Phoenix.Endpoint
  alias Clarity.Vertex.Root

  describe inspect(&EndpointIntrospector.introspect_vertex/2) do
    test "returns empty list for non-module vertices" do
      graph = Clarity.Graph.new()

      assert [] = EndpointIntrospector.introspect_vertex(%Root{}, graph)
    end

    test "creates endpoint vertex for Phoenix endpoint modules" do
      graph = Clarity.Graph.new()

      clarity_app_vertex = %Vertex.Application{app: :clarity, description: "Clarity App", version: "1.0.0"}
      Clarity.Graph.add_vertex(graph, clarity_app_vertex, %Root{})

      module_vertex = %Vertex.Module{module: DemoWeb.Endpoint}

      assert [
               {:vertex, %Endpoint{endpoint: DemoWeb.Endpoint}},
               {:edge, ^module_vertex, %Endpoint{endpoint: DemoWeb.Endpoint}, "endpoint"},
               {:edge, ^clarity_app_vertex, %Endpoint{endpoint: DemoWeb.Endpoint}, "endpoint"}
             ] = EndpointIntrospector.introspect_vertex(module_vertex, graph)
    end

    test "returns empty list for non-endpoint modules" do
      graph = Clarity.Graph.new()
      module_vertex = %Vertex.Module{module: String}

      assert [] = EndpointIntrospector.introspect_vertex(module_vertex, graph)
    end
  end
end
