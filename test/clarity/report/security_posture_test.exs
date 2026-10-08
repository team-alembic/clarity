defmodule Clarity.Report.SecurityPostureTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Clarity.Graph
  alias Clarity.Perspective.Lens
  alias Clarity.Perspective.Lensmaker.Architect
  alias Clarity.Report.SecurityPosture
  alias Clarity.Vertex.Ash.Resource
  alias Clarity.Vertex.Root
  alias Demo.Accounts.User

  @spec render_report(Graph.t(), Lens.t()) :: String.t()
  defp render_report(graph, lens) do
    render_component(SecurityPosture, id: "report", graph: graph, lens: lens, prefix: "/c")
  end

  @spec graph_of([module()]) :: Graph.t()
  defp graph_of(resources) do
    graph = Graph.new()
    for resource <- resources, do: Graph.add_vertex(graph, %Resource{resource: resource}, %Root{})
    graph
  end

  # The report as rendered once its analysis is done.
  @spec posture(map()) :: LazyHTML.t()
  defp posture(analysis) do
    (&SecurityPosture.posture/1)
    |> render_component(analysis: analysis, prefix: "/c", lens: Architect.make_lens())
    |> LazyHTML.from_fragment()
  end

  @spec text(LazyHTML.t(), String.t()) :: String.t()
  defp text(doc, selector), do: doc |> LazyHTML.query(selector) |> LazyHTML.text() |> String.split() |> Enum.join(" ")

  # The to-do with the given title, as text.
  @spec todo(LazyHTML.t(), atom(), String.t()) :: String.t()
  defp todo(doc, severity, title) do
    doc
    |> LazyHTML.query(".report-todo[data-severity='#{severity}']")
    |> Enum.find(&(&1 |> LazyHTML.query(".report-todo-title") |> LazyHTML.text() =~ title))
    |> case do
      nil -> flunk("no #{severity} to-do titled #{inspect(title)}")
      todo -> todo |> LazyHTML.text() |> String.split() |> Enum.join(" ")
    end
  end

  describe "posture/1" do
    setup do
      graph = graph_of([Demo.Helpdesk.CustomerContact, User, Demo.Accounts.Membership])
      %{doc: graph |> SecurityPosture.analyse() |> posture()}
    end

    test "says how many things there are to do, without explaining itself first", %{doc: doc} do
      assert text(doc, ".report-status") == "5 things to do"
      refute LazyHTML.text(doc) =~ "This report reviews"
    end

    test "puts sensitive fields anyone can read first", %{doc: doc} do
      [first | _todos] = doc |> LazyHTML.query(".report-todo") |> Enum.to_list()

      assert LazyHTML.text(first) =~ "Sensitive fields anyone can read"
      assert todo(doc, :high, "Sensitive fields anyone can read") =~ "Helpdesk.CustomerContact email phone"
    end

    test "lists resources with no policies, saying how to add them", %{doc: doc} do
      todo = todo(doc, :medium, "Resources with no policies")

      # grouped by domain, each named within it
      assert todo =~ "Helpdesk CustomerContact"
      refute todo =~ "User"
      assert todo =~ "Ash.Policy.Authorizer"
    end

    test "lists actions anonymous callers may reach on resources with policies", %{doc: doc} do
      assert todo(doc, :medium, "Actions anonymous callers can reach") =~ "Accounts.Membership revoke"
    end

    test "lists sensitive fields signed-in actors can read without a field policy", %{doc: doc} do
      assert todo(doc, :low, "Sensitive fields without field policies") =~ "Accounts.User"
    end

    test "lists bypasses to review", %{doc: doc} do
      todo = todo(doc, :low, "Bypass policies to review")

      assert todo =~ "Accounts.User"
      assert todo =~ "Accounts.Membership"
    end

    test "links each resource to its page", %{doc: doc} do
      assert doc
             |> LazyHTML.query("a.report-chip[href='/c/architect/ash-resource:demo-accounts-user']")
             |> Enum.count() > 0
    end

    test "keeps who can reach what, and every resource's posture, in closed sections", %{doc: doc} do
      assert doc |> LazyHTML.query("details#reach.report-section:not([open]) table.report-table") |> Enum.count() == 1
      assert doc |> LazyHTML.query("details#resources.report-section:not([open]) table.report-table") |> Enum.count() == 1
      # a resource no actor can reach says so, rather than listing nothing
      assert text(doc, "#reach") =~ "none"
    end
  end

  test "flags a domain that checks policies only when asked, first of all" do
    analysis =
      [User]
      |> graph_of()
      |> SecurityPosture.analyse()
      |> Map.put(:lax_domains, [%{name: "Accounts", id: "ash-domain:demo-accounts"}])

    doc = posture(analysis)

    assert todo(doc, :high, "Domains that check policies only when asked") =~ "Accounts"
    assert todo(doc, :high, "Domains that check policies only when asked") =~ "authorize :by_default"
  end

  test "says there's nothing to do with no resources" do
    doc = Graph.new() |> SecurityPosture.analyse() |> posture()

    assert text(doc, ".report-status[data-tone='ok']") == "Nothing to do"
    assert text(doc, ".report-status-meta") =~ "No Ash resources found"
  end

  describe "render" do
    test "shows the analysis is under way until it finishes" do
      html = render_report(Graph.new(), Architect.make_lens())

      assert html =~ "Analysing"
    end
  end
end
