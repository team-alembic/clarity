defmodule Clarity.Introspector.Spark.ExtensionTest do
  use ExUnit.Case, async: true

  alias Ash.Domain.Dsl
  alias Clarity.Introspector.Spark.Extension, as: ExtensionIntrospector
  alias Clarity.Vertex
  alias Clarity.Vertex.Spark.Extension

  describe inspect(&ExtensionIntrospector.introspect_vertex/2) do
    test "creates extension vertices for module vertices with Spark Extensions" do
      graph = Clarity.Graph.new()
      app_vertex = %Vertex.Application{app: :ash, description: "Ash", version: "1.0.0"}

      module_vertex = %Vertex.Module{
        module: Dsl,
        version: :unknown,
        behaviour?: true
      }

      Clarity.Graph.add_vertex(graph, app_vertex, %Vertex.Root{})

      assert {:ok,
              [
                {:vertex, %Extension{extension: Dsl}},
                {:edge, ^app_vertex, %Extension{extension: Dsl}, :spark_extension},
                {:edge, ^module_vertex, %Extension{extension: Dsl}, :spark_extension}
                | _
              ]} = ExtensionIntrospector.introspect_vertex(module_vertex, graph)
    end

    test "returns empty list for module vertices without Spark Extensions" do
      graph = Clarity.Graph.new()

      module_vertex = %Vertex.Module{module: String, version: :unknown, behaviour?: false}

      assert {:ok, []} = ExtensionIntrospector.introspect_vertex(module_vertex, graph)
    end

    test "returns empty list for non-extension modules" do
      graph = Clarity.Graph.new()

      module_vertex = %Vertex.Module{
        module: Clarity.Config,
        version: :unknown,
        behaviour?: false
      }

      assert {:ok, []} = ExtensionIntrospector.introspect_vertex(module_vertex, graph)
    end
  end
end
