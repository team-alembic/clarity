defmodule Clarity.Introspector.Spark.DslTest do
  use ExUnit.Case, async: true

  alias Clarity.Introspector.Spark.Dsl, as: DslIntrospector
  alias Clarity.Vertex
  alias Clarity.Vertex.Spark.Dsl

  describe inspect(&DslIntrospector.introspect_vertex/2) do
    test "creates DSL vertices for DSL base modules" do
      graph = Clarity.Graph.new()
      app_vertex = %Vertex.Application{app: :ash, description: "Ash", version: "1.0.0"}

      module_vertex = %Vertex.Module{
        module: Ash.Domain,
        version: :unknown,
        behaviour?: true
      }

      Clarity.Graph.add_vertex(graph, app_vertex, %Vertex.Root{})

      assert {:ok,
              [
                {:vertex, %Dsl{dsl: Ash.Domain}},
                {:edge, ^app_vertex, %Dsl{dsl: Ash.Domain}, :spark_dsl},
                {:edge, ^module_vertex, %Dsl{dsl: Ash.Domain}, :spark_dsl}
                | _
              ]} = DslIntrospector.introspect_vertex(module_vertex, graph)
    end

    test "returns empty list for module vertices without Spark DSLs" do
      graph = Clarity.Graph.new()

      module_vertex = %Vertex.Module{module: String, version: :unknown, behaviour?: false}

      assert {:ok, []} = DslIntrospector.introspect_vertex(module_vertex, graph)
    end

    test "returns empty list for implementations (not DSL bases)" do
      graph = Clarity.Graph.new()

      # Demo.Accounts.Domain is an implementation, not a DSL base
      module_vertex = %Vertex.Module{
        module: Demo.Accounts.Domain,
        version: :unknown,
        behaviour?: false
      }

      assert {:ok, []} = DslIntrospector.introspect_vertex(module_vertex, graph)
    end

    test "returns empty list for non-Spark modules" do
      graph = Clarity.Graph.new()

      module_vertex = %Vertex.Module{
        module: Clarity.Config,
        version: :unknown,
        behaviour?: false
      }

      assert {:ok, []} = DslIntrospector.introspect_vertex(module_vertex, graph)
    end

    test "creates edges from DSL base to its default extensions" do
      graph = Clarity.Graph.new()
      root = %Vertex.Root{}

      dsl_vertex = %Dsl{dsl: Ash.Domain}
      extension_vertex = %Vertex.Spark.Extension{extension: Ash.Domain.Dsl}

      Clarity.Graph.add_vertex(graph, extension_vertex, root)

      {:ok, edges} = DslIntrospector.introspect_vertex(dsl_vertex, graph)

      assert Enum.any?(edges, &match?({:edge, ^dsl_vertex, ^extension_vertex, :uses_extension}, &1))
    end

    test "returns unmet dependencies when default extension not in graph" do
      graph = Clarity.Graph.new()
      dsl_vertex = %Dsl{dsl: Ash.Domain}

      assert {:error, :unmet_dependencies} = DslIntrospector.introspect_vertex(dsl_vertex, graph)
    end

    test "returns empty list when DSL has no default extensions" do
      # Create a test module that has spark_dsl but no default extensions
      # Use Spark.Dsl itself as it likely has no default extensions
      graph = Clarity.Graph.new()
      dsl_vertex = %Dsl{dsl: Spark.Dsl}

      assert {:ok, []} = DslIntrospector.introspect_vertex(dsl_vertex, graph)
    end
  end
end
