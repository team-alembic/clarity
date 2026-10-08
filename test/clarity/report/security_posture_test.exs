defmodule Clarity.Report.SecurityPostureTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Clarity.Graph
  alias Clarity.Perspective.Lens
  alias Clarity.Perspective.Lensmaker.Architect
  alias Clarity.Report.Action
  alias Clarity.Report.SecurityPosture
  alias Clarity.Vertex.Ash.Resource
  alias Clarity.Vertex.Root
  alias Demo.Accounts.Membership
  alias Demo.Accounts.User
  alias Demo.Helpdesk.CustomerContact

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

  # The action titled `title`, as {its severity, each group's label and items' text}.
  @spec action([Action.t()], String.t()) :: {atom(), [{String.t() | nil, [String.t()]}]}
  defp action(actions, title) do
    case Enum.find(actions, &(&1.title == title)) do
      nil -> flunk("no action titled #{inspect(title)}")
      action -> {action.severity, Enum.map(action.groups, &{&1[:label], Enum.map(&1.items, fn item -> item.text end)})}
    end
  end

  describe "actions/2" do
    setup do
      graph = graph_of([CustomerContact, User, Membership])
      %{actions: SecurityPosture.actions(graph, [])}
    end

    test "counts each field, resource and action as a to-do, most severe first", %{actions: actions} do
      assert Enum.map(actions, & &1.severity) == [:high, :medium, :medium, :low, :low]
      assert Action.tally(actions) == %{high: 2, medium: 2, low: 4, total: 8, worst: :high}
    end

    test "puts sensitive fields anyone can read first, under their resource", %{actions: actions} do
      assert action(actions, "Sensitive fields anyone can read") ==
               {:high, [{"Helpdesk.CustomerContact", ["email", "phone"]}]}
    end

    test "lists resources with no policies by domain, saying how to add them", %{actions: actions} do
      assert action(actions, "Resources with no policies") == {:medium, [{"Helpdesk", ["CustomerContact"]}]}
      assert Enum.find(actions, &(&1.title == "Resources with no policies")).fix =~ "Ash.Policy.Authorizer"
    end

    test "lists actions anonymous callers may reach on resources with policies", %{actions: actions} do
      assert action(actions, "Actions anonymous callers can reach") == {:medium, [{"Accounts.Membership", ["revoke"]}]}
    end

    test "lists sensitive fields signed-in actors can read without a field policy", %{actions: actions} do
      assert {:low, [{"Accounts.User", fields}]} = action(actions, "Sensitive fields without field policies")
      assert "date_of_birth" in fields
    end

    test "lists bypasses to review", %{actions: actions} do
      assert {:low, [{nil, resources}]} = action(actions, "Bypass policies to review")
      assert "Accounts.User" in resources
      assert "Accounts.Membership" in resources
    end

    test "links each item to its vertex", %{actions: actions} do
      %{groups: [%{id: resource_id, items: [%{id: field_id} | _fields]}]} =
        Enum.find(actions, &(&1.title == "Sensitive fields anyone can read"))

      assert resource_id == "ash-resource:demo-helpdesk-customer-contact"
      assert field_id == "ash-attribute:demo-helpdesk-customer-contact:email"
    end

    test "has nothing to do with no resources" do
      assert SecurityPosture.actions(Graph.new(), []) == []
    end
  end

  describe "posture/1" do
    setup do
      graph = graph_of([CustomerContact, User, Membership])
      %{doc: graph |> SecurityPosture.analyse() |> posture()}
    end

    test "shows what there is to know, not what there is to do", %{doc: doc} do
      assert doc |> LazyHTML.query(".report-todo") |> Enum.empty?()
      refute LazyHTML.text(doc) =~ "This report reviews"
    end

    test "shows who can reach what, and every resource's posture, open to scroll through", %{doc: doc} do
      assert doc |> LazyHTML.query("details#reach[open] table.report-table") |> Enum.count() == 1
      assert doc |> LazyHTML.query("details#resources[open] table.report-table") |> Enum.count() == 1
      # a resource no actor can reach says so, rather than listing nothing
      assert text(doc, "#reach") =~ "none"
    end

    test "links each resource to its page", %{doc: doc} do
      assert doc
             |> LazyHTML.query("a.report-link[href='/c/architect/ash-resource:demo-accounts-user']")
             |> Enum.count() > 0
    end

    test "says so when there are no resources" do
      doc = Graph.new() |> SecurityPosture.analyse() |> posture()

      assert text(doc, ".report-status-meta") =~ "No Ash resources found"
    end
  end

  describe "render" do
    test "shows the analysis is under way until it finishes" do
      html = render_report(Graph.new(), Architect.make_lens())

      assert html =~ "Analysing"
    end
  end
end
