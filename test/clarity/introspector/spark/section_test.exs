defmodule Clarity.Introspector.Spark.SectionTest do
  use ExUnit.Case, async: true

  alias Clarity.Introspector.Spark.Section, as: SectionIntrospector
  alias Clarity.Vertex
  alias Clarity.Vertex.Spark.Dsl
  alias Clarity.Vertex.Spark.Section, as: SectionVertex
  alias Demo.Accounts.Domain
  alias Demo.Accounts.User

  describe inspect(&SectionIntrospector.introspect_vertex/2) do
    test "creates edge to DSL base and section vertices for implementations" do
      graph = Clarity.Graph.new()
      root = %Vertex.Root{}

      module_vertex = %Vertex.Module{
        module: Domain,
        version: :unknown,
        behaviour?: false
      }

      dsl_vertex = %Dsl{dsl: Ash.Domain}

      Clarity.Graph.add_vertex(graph, dsl_vertex, root)

      assert {:ok,
              [
                {:edge, ^module_vertex, ^dsl_vertex, :uses_dsl},
                {:vertex, %SectionVertex{module: Domain, path: [:resources]}},
                {:edge, ^module_vertex, %SectionVertex{path: [:resources]}, :section},
                {:edge, %SectionVertex{path: [:resources]}, ^dsl_vertex, :section_of}
              ]} = SectionIntrospector.introspect_vertex(module_vertex, graph)
    end

    test "creates multiple sections for resources" do
      graph = Clarity.Graph.new()
      root = %Vertex.Root{}

      module_vertex = %Vertex.Module{
        module: User,
        version: :unknown,
        behaviour?: false
      }

      dsl_vertex = %Dsl{dsl: Ash.Resource}

      Clarity.Graph.add_vertex(graph, dsl_vertex, root)

      assert {:ok,
              [
                {:edge, ^module_vertex, ^dsl_vertex, :uses_dsl},
                {:vertex, %SectionVertex{module: User, path: [:actions]} = actions_section},
                {:edge, ^module_vertex, actions_section, :section},
                {:edge, actions_section, ^dsl_vertex, :section_of},
                {:vertex, %SectionVertex{module: User, path: [:aggregates]} = aggregates_section},
                {:edge, ^module_vertex, aggregates_section, :section},
                {:edge, aggregates_section, ^dsl_vertex, :section_of},
                {:vertex, %SectionVertex{module: User, path: [:attributes]} = attributes_section},
                {:edge, ^module_vertex, attributes_section, :section},
                {:edge, attributes_section, ^dsl_vertex, :section_of},
                {:vertex, %SectionVertex{module: User, path: [:calculations]} = calculations_section},
                {:edge, ^module_vertex, calculations_section, :section},
                {:edge, calculations_section, ^dsl_vertex, :section_of},
                {:vertex, %SectionVertex{module: User, path: [:code_interface]} = code_interface_section},
                {:edge, ^module_vertex, code_interface_section, :section},
                {:edge, code_interface_section, ^dsl_vertex, :section_of},
                {:vertex, %SectionVertex{module: User, path: [:multitenancy]} = multitenancy_section},
                {:edge, ^module_vertex, multitenancy_section, :section},
                {:edge, multitenancy_section, ^dsl_vertex, :section_of},
                {:vertex, %SectionVertex{module: User, path: [:policies]} = policies_section},
                {:edge, ^module_vertex, policies_section, :section},
                {:edge, policies_section, ^dsl_vertex, :section_of},
                {:vertex, %SectionVertex{module: User, path: [:relationships]} = relationships_section},
                {:edge, ^module_vertex, relationships_section, :section},
                {:edge, relationships_section, ^dsl_vertex, :section_of},
                {:vertex, %SectionVertex{module: User, path: [:validations]} = validations_section},
                {:edge, ^module_vertex, validations_section, :section},
                {:edge, validations_section, ^dsl_vertex, :section_of}
              ]} = SectionIntrospector.introspect_vertex(module_vertex, graph)
    end

    test "creates edges from module to sections and sections to DSL base" do
      graph = Clarity.Graph.new()
      root = %Vertex.Root{}

      module_vertex = %Vertex.Module{
        module: Domain,
        version: :unknown,
        behaviour?: false
      }

      dsl_vertex = %Dsl{dsl: Ash.Domain}

      Clarity.Graph.add_vertex(graph, dsl_vertex, root)

      assert {:ok,
              [
                {:edge, ^module_vertex, ^dsl_vertex, :uses_dsl},
                {:vertex, %SectionVertex{module: Domain, path: [:resources]} = section_vertex},
                {:edge, ^module_vertex, section_vertex, :section},
                {:edge, section_vertex, ^dsl_vertex, :section_of}
              ]} = SectionIntrospector.introspect_vertex(module_vertex, graph)
    end

    test "returns unmet dependencies when DSL base not in graph" do
      graph = Clarity.Graph.new()

      module_vertex = %Vertex.Module{
        module: Domain,
        version: :unknown,
        behaviour?: false
      }

      assert {:error, :unmet_dependencies} =
               SectionIntrospector.introspect_vertex(module_vertex, graph)
    end

    test "returns empty list for non-Spark modules" do
      graph = Clarity.Graph.new()

      module_vertex = %Vertex.Module{
        module: String,
        version: :unknown,
        behaviour?: false
      }

      assert {:ok, []} = SectionIntrospector.introspect_vertex(module_vertex, graph)
    end

    test "returns empty list for DSL bases (not implementations)" do
      graph = Clarity.Graph.new()

      module_vertex = %Vertex.Module{
        module: Ash.Domain,
        version: :unknown,
        behaviour?: true
      }

      assert {:ok, []} = SectionIntrospector.introspect_vertex(module_vertex, graph)
    end
  end
end
