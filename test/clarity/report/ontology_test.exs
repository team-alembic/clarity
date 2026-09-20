defmodule Clarity.Report.OntologyTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Ash.Resource.Info
  alias Clarity.Graph
  alias Clarity.Perspective.Lens
  alias Clarity.Perspective.Lensmaker.Architect
  alias Clarity.Report.Ontology
  alias Clarity.Test.OntologyFixture
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Attribute
  alias Clarity.Vertex.Ash.Resource
  alias Clarity.Vertex.Ash.Type
  alias Clarity.Vertex.Root
  alias Demo.Accounts.User

  @spec render_report(Graph.t(), Lens.t()) :: String.t()
  defp render_report(graph, lens) do
    render_component(Ontology, id: "report", graph: graph, lens: lens, prefix: "/c")
  end

  @spec graph_for(module()) :: Graph.t()
  defp graph_for(resource) do
    graph = Graph.new()
    Graph.add_vertex(graph, %Resource{resource: resource}, %Root{})
    graph
  end

  describe "category/0" do
    test "files the report under Architecture" do
      assert Ontology.category() == "Architecture"
    end
  end

  describe "render" do
    test "lists the resource as an entity with its domain and data layer" do
      html = render_report(graph_for(User), Architect.make_lens())

      assert html =~ "Demo.Accounts.User"
      assert html =~ "<td>Demo.Accounts</td>"
      assert html =~ "Ash.DataLayer.Ets"
      # executive dashboard: KPI cards + a stacked bar
      assert html =~ "Documentation coverage"
      assert html =~ "data-segment"
    end

    test "lists fully-qualified public terms of every kind" do
      html = render_report(graph_for(OntologyFixture), Architect.make_lens())

      # attribute, calculation, aggregate, relationship
      assert html =~ "Clarity.Test.OntologyFixture.name"
      assert html =~ "Clarity.Test.OntologyFixture.display_name"
      assert html =~ "Clarity.Test.OntologyFixture.child_count"
      assert html =~ "Clarity.Test.OntologyFixture.parent"
      assert html =~ "Clarity.Test.OntologyFixture.children"
      # kinds are spelled out
      assert html =~ ">attribute</"
      assert html =~ ">calculation</"
      assert html =~ ">aggregate</"
      assert html =~ ">relationship</"
      # private terms are not part of the dictionary
      refute html =~ "Clarity.Test.OntologyFixture.secret"
    end

    test "writes relationships out as sentences with the cardinality in words" do
      html = render_report(graph_for(OntologyFixture), Architect.make_lens())

      assert html =~ "belongs to one"
      assert html =~ "has many"
      # the destination links to its vertex page (the resource is in the graph)
      assert html =~ "ash-resource:clarity-test-ontology-fixture"
    end

    test "spells out enum members as vocabulary" do
      html = render_report(graph_for(OntologyFixture), Architect.make_lens())

      assert html =~ ":draft"
      assert html =~ ":live"
    end

    test "flags sensitive and required fields" do
      html = render_report(graph_for(User), Architect.make_lens())

      assert html =~ "sensitive"
      assert html =~ "primary key"
      assert html =~ "required"
    end

    test "flags undocumented terms instead of hiding them" do
      html = render_report(graph_for(User), Architect.make_lens())

      # the documented term shows its description
      assert html =~ "Lorem ipsum"
      # undocumented public terms are marked in the dictionary...
      assert html =~ "(undocumented)"
      # ...and listed in the coverage worklist, private ones included
      assert html =~ "(private)"
      assert html =~ ">org</code>"
      assert html =~ ">api_key</code>"
    end

    test "reports documentation coverage per entity and overall" do
      html = render_report(graph_for(OntologyFixture), Architect.make_lens())

      # 8 public terms, of which 2 have descriptions
      assert html =~ "2 of 8 public terms have a description"
      assert html =~ "6 are still undocumented"
      assert html =~ "still missing a description"
    end

    test "links terms and types that are in the graph" do
      graph = graph_for(User)
      resource_vertex = Graph.get_vertex(graph, Vertex.id(%Resource{resource: User}))

      attribute = Enum.find(Info.attributes(User), &(&1.name == :representative))
      Graph.add_vertex(graph, %Attribute{attribute: attribute, resource: User}, resource_vertex)
      Graph.add_vertex(graph, %Type{type: Ash.Type.Atom}, resource_vertex)

      html = render_report(graph, Architect.make_lens())

      assert html =~ "ash-attribute:demo-accounts-user:representative"
      # the :atom type links through to its Vertex.Ash.Type page
      assert html =~ "ash-type:ash-type-atom"
    end

    test "says there is nothing to report with no resources" do
      html = render_report(Graph.new(), Architect.make_lens())

      assert html =~ "hasn't found any Ash resources"
    end
  end
end
