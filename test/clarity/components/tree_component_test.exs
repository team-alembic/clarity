defmodule Clarity.TreeComponentTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Clarity.Graph
  alias Clarity.Perspective.Lensmaker
  alias Clarity.TreeComponent
  alias Clarity.Vertex

  describe "short names" do
    test "siblings whose short names clash are told apart by the module before" do
      app = %Vertex.Application{
        app: :clarity,
        description: "Clarity App",
        version: Version.parse!("0.4.0")
      }

      graph = Graph.new()
      Graph.add_vertex(graph, app, %Vertex.Root{})
      Graph.add_edge(graph, %Vertex.Root{}, app, :child)

      for module <- [Demo.Billing.Domain, Demo.Org.Domain, Demo.Accounts] do
        vertex = %Vertex.Module{module: module}
        Graph.add_vertex(graph, vertex, app)
        Graph.add_edge(graph, app, vertex, :module)
      end

      {:ok, lens} = Lensmaker.get_lens_by_id("debug")

      labels =
        TreeComponent
        |> render_component(
          id: "tree",
          graph: graph,
          lens: lens,
          prefix: "/",
          active_vertex: app,
          breadcrumbs: [%Vertex.Root{}, app],
          opened: MapSet.new(),
          collapsed: MapSet.new(),
          name_style: :short
        )
        |> LazyHTML.from_fragment()
        |> LazyHTML.query("a[data-tooltip-type='Module']")
        |> Enum.map(&(&1 |> LazyHTML.text() |> String.trim()))

      assert labels == ["Accounts", "Billing.Domain", "Org.Domain"]
    end
  end

  describe "group rows" do
    # An application with modules and, optionally, a domain, rendered open.
    @spec render_app_tree([{Vertex.t(), atom()}]) :: LazyHTML.t()
    defp render_app_tree(edges) do
      app = %Vertex.Application{app: :clarity, description: "Clarity App", version: Version.parse!("0.4.0")}

      graph = Graph.new()
      Graph.add_vertex(graph, app, %Vertex.Root{})
      Graph.add_edge(graph, %Vertex.Root{}, app, :child)

      for {vertex, label} <- edges do
        Graph.add_vertex(graph, vertex, app)
        Graph.add_edge(graph, app, vertex, label)
      end

      {:ok, lens} = Lensmaker.get_lens_by_id("debug")

      TreeComponent
      |> render_component(
        id: "tree",
        graph: graph,
        lens: lens,
        prefix: "/",
        active_vertex: app,
        breadcrumbs: [%Vertex.Root{}, app],
        opened: MapSet.new(),
        collapsed: MapSet.new(),
        name_style: :short
      )
      |> LazyHTML.from_fragment()
    end

    @spec group_labels(LazyHTML.t()) :: [String.t()]
    defp group_labels(tree),
      do: tree |> LazyHTML.query("[id^='tree-group-'] > summary") |> Enum.map(&String.trim(LazyHTML.text(&1)))

    test "a node's only group gets no row of its own; its items sit directly under the node" do
      tree = render_app_tree([{%Vertex.Module{module: Demo.Accounts}, :module}])

      # Root has one group (the application) and so does the application (modules).
      assert group_labels(tree) == []
      assert tree |> LazyHTML.query("a[data-tooltip-type='Module']") |> Enum.count() == 1
    end

    test "a node with several groups keeps a row for each" do
      tree =
        render_app_tree([
          {%Vertex.Module{module: Demo.Accounts}, :module},
          {%Vertex.Ash.Domain{domain: Demo.Accounts}, :domain}
        ])

      assert tree |> group_labels() |> Enum.sort() == ["domain", "module"]
    end
  end

  describe "status_badge/1" do
    test "renders nothing without an entry" do
      html = render_component(&TreeComponent.status_badge/1, entry: nil)

      refute html =~ "svg"
    end

    test "renders a pill with no count for a flagged leaf (no nested issues)" do
      html = render_component(&TreeComponent.status_badge/1, entry: %{severity: :error, count: 0})

      assert html =~ "rounded-full"
      assert html =~ "bg-red-100"
      # the count span (tabular-nums) is only shown when there are nested issues
      refute html =~ "tabular-nums"
    end

    test "shows the count of nested issues" do
      html = render_component(&TreeComponent.status_badge/1, entry: %{severity: :error, count: 3})

      assert html =~ "bg-red-100"
      assert html =~ "tabular-nums"
      assert html =~ "3"
    end

    test "renders warning and info severities" do
      warning =
        render_component(&TreeComponent.status_badge/1, entry: %{severity: :warning, count: 1})

      assert warning =~ "bg-yellow-100"

      info = render_component(&TreeComponent.status_badge/1, entry: %{severity: :info, count: 1})

      assert info =~ "bg-blue-100"
    end
  end

  describe "status_badge/1 hint" do
    test "describes nested issues in a hover hint and an accessible name" do
      html = render_component(&TreeComponent.status_badge/1, entry: %{severity: :error, count: 3})

      badge = html |> LazyHTML.from_fragment() |> LazyHTML.query("[data-tooltip-text='3 nested issues']")

      assert LazyHTML.attribute(badge, "aria-label") == ["3 nested issues"]
    end
  end
end
