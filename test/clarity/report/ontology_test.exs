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

  @spec render_report(Graph.t(), Lens.t(), keyword()) :: String.t()
  defp render_report(graph, lens, assigns \\ []) do
    render_component(Ontology, [id: "report", graph: graph, lens: lens, prefix: "/c"] ++ assigns)
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

  @spec doc(String.t()) :: LazyHTML.t()
  defp doc(html), do: LazyHTML.from_fragment(html)

  @spec text(LazyHTML.t(), String.t()) :: String.t()
  defp text(doc, selector), do: doc |> LazyHTML.query(selector) |> LazyHTML.text() |> String.split() |> Enum.join(" ")

  @spec texts(LazyHTML.t(), String.t()) :: [String.t()]
  defp texts(doc, selector),
    do: doc |> LazyHTML.query(selector) |> Enum.map(&(&1 |> LazyHTML.text() |> String.split() |> Enum.join(" ")))

  describe "render" do
    test "leads with what to do, without explaining itself first" do
      doc = User |> graph_for() |> render_report(Architect.make_lens()) |> doc()

      assert text(doc, ".report-status") =~ "to do"
      refute LazyHTML.text(doc) =~ "This report is"
      # executive dashboard: KPI cards + a stacked bar
      assert text(doc, "figcaption") == "Documentation coverage"
      assert doc |> LazyHTML.query("[data-segment]") |> Enum.count() > 0
    end

    test "lists the resource as an entity with its domain and data layer" do
      doc = User |> graph_for() |> render_report(Architect.make_lens()) |> doc()

      assert doc |> texts("#entities tbody tr td") |> Enum.take(2) == ["Demo.Accounts.User", "Demo.Accounts"]
      # Ash's own data layers by their short name
      assert "Ets" in texts(doc, "#entities tbody td")
      # the dictionary waits, closed, below the to-dos
      assert doc |> LazyHTML.query("details#entities:not([open])") |> Enum.count() == 1
      assert doc |> LazyHTML.query("details#terms:not([open])") |> Enum.count() == 1
    end

    test "names domains within the application, and entities and terms within what holds them, when short" do
      doc = User |> graph_for() |> render_report(Architect.make_lens(), name_style: :short) |> doc()

      assert doc |> texts("#entities tbody tr td") |> Enum.take(2) == ["User", "Accounts"]
      # Terms sit under their entity's heading, which keeps its full name.
      assert text(doc, "#terms details > summary") =~ "Demo.Accounts.User"
      assert "email" in texts(doc, "#terms tbody td:first-child")
      refute text(doc, "#terms") =~ "Demo.Accounts.User.email"
    end

    test "lists fully-qualified public terms of every kind" do
      doc = OntologyFixture |> graph_for() |> render_report(Architect.make_lens()) |> doc()
      terms = texts(doc, "#terms tbody td:first-child")

      # attribute, calculation, aggregate, relationship
      for name <- ~w(name display_name child_count parent children) do
        assert "Clarity.Test.OntologyFixture.#{name}" in terms
      end

      # kinds are spelled out
      for kind <- ~w(attribute calculation aggregate relationship),
          do: assert(kind in texts(doc, "#terms tbody td:nth-child(2)"))

      # private terms are not part of the dictionary
      refute "Clarity.Test.OntologyFixture.secret" in terms
    end

    test "writes relationships out as sentences with the cardinality in words" do
      doc = OntologyFixture |> graph_for() |> render_report(Architect.make_lens()) |> doc()
      types = texts(doc, "#terms tbody td:nth-child(3)")

      assert Enum.any?(types, &String.starts_with?(&1, "belongs to one"))
      assert Enum.any?(types, &String.starts_with?(&1, "has many"))
      # the destination links to its vertex page (the resource is in the graph)
      assert doc
             |> LazyHTML.query("#terms a[href='/c/architect/ash-resource:clarity-test-ontology-fixture']")
             |> Enum.count() > 0
    end

    test "spells out enum members as vocabulary" do
      notes = OntologyFixture |> graph_for() |> render_report(Architect.make_lens()) |> doc() |> text("#terms")

      assert notes =~ "one of :draft"
      assert notes =~ ":live"
    end

    test "flags sensitive and required fields" do
      tags = User |> graph_for() |> render_report(Architect.make_lens()) |> doc() |> texts("#terms .report-tag")

      assert "sensitive" in tags
      assert "primary key" in tags
      assert "required" in tags
    end

    test "flags undocumented terms, and lists them, private ones too, as a to-do" do
      doc = User |> graph_for() |> render_report(Architect.make_lens()) |> doc()

      # the documented term shows its description
      assert text(doc, "#terms") =~ "Lorem ipsum"
      # undocumented public terms are marked in the dictionary...
      assert "undocumented" in texts(doc, "#terms .report-tag")
      # ...and listed in the to-do, private ones included but faded
      todo = ".report-todo[data-severity='low']"
      assert text(doc, "#{todo} .report-todo-title") =~ "Terms without a description"
      assert "org" in texts(doc, "#{todo} .report-chip-muted")
      assert "api_key" in texts(doc, "#{todo} .report-chip")
    end

    test "lists resources with no description as a to-do" do
      doc = OntologyFixture |> graph_for() |> render_report(Architect.make_lens()) |> doc()
      todo = ".report-todo[data-severity='medium']"

      assert text(doc, "#{todo} .report-todo-title") =~ "Resources without a description"
      assert texts(doc, "#{todo} .report-chip") == ["Clarity.Test.OntologyFixture"]
    end

    test "reports documentation coverage per entity and overall" do
      doc = OntologyFixture |> graph_for() |> render_report(Architect.make_lens()) |> doc()

      # 8 public terms, of which 2 have descriptions
      assert text(doc, "#entities tbody td:last-child") == "2/8"
      assert "6 Undocumented" in texts(doc, ".grid > div")
      assert "2 Documented" in texts(doc, ".grid > div")
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

    test "says there's nothing to do with no resources" do
      doc = Graph.new() |> render_report(Architect.make_lens()) |> doc()

      assert text(doc, ".report-status[data-tone='ok']") == "Nothing to do"
      assert text(doc, ".report-status-meta") =~ "No Ash resources found"
    end
  end
end
