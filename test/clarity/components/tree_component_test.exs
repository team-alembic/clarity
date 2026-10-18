defmodule Clarity.TreeComponentTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Ash.Policy.Info, as: PolicyInfo
  alias Clarity.Graph
  alias Clarity.Perspective.Lensmaker
  alias Clarity.TreeComponent
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Resource
  alias Clarity.Vertex.Phoenix.Router
  alias Demo.Accounts.ApiKey
  alias Demo.Accounts.User

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

    test "rows go in the order of their labels, not their full names" do
      labels =
        [User, Demo.Billing.Invoice, Demo.Projects.Attachment]
        |> Enum.map(&{%Vertex.Module{module: &1}, :module})
        |> render_app_tree()
        |> LazyHTML.query("a[data-tooltip-type='Module']")
        |> Enum.map(&(&1 |> LazyHTML.text() |> String.trim()))

      assert labels == ["Attachment", "Invoice", "User"]
    end
  end

  describe "group rows" do
    # An application with modules and, optionally, a domain, rendered open.
    @spec render_app_tree([{Vertex.t(), atom()}], Vertex.t() | nil, String.t()) :: LazyHTML.t()
    defp render_app_tree(edges, active \\ nil, lens_id \\ "debug") do
      app = %Vertex.Application{app: :clarity, description: "Clarity App", version: Version.parse!("0.4.0")}

      graph = Graph.new()
      Graph.add_vertex(graph, app, %Vertex.Root{})
      Graph.add_edge(graph, %Vertex.Root{}, app, :child)

      for {vertex, label} <- edges do
        Graph.add_vertex(graph, vertex, app)
        Graph.add_edge(graph, app, vertex, label)
      end

      {:ok, lens} = Lensmaker.get_lens_by_id(lens_id)

      TreeComponent
      |> render_component(
        id: "tree",
        graph: graph,
        lens: lens,
        prefix: "/",
        active_vertex: active || app,
        breadcrumbs: [%Vertex.Root{}, app | List.wrap(active)],
        opened: MapSet.new(),
        collapsed: MapSet.new(),
        name_style: :short
      )
      |> LazyHTML.from_fragment()
    end

    @spec group_labels(LazyHTML.t()) :: [String.t()]
    defp group_labels(tree),
      do:
        tree
        |> LazyHTML.query("[id^='tree-group-'] > summary")
        |> Enum.map(&(&1 |> LazyHTML.text() |> String.split() |> Enum.join(" ")))

    test "a node's only group gets no row of its own; its items sit directly under the node" do
      tree = render_app_tree([{%Vertex.Module{module: Demo.Accounts}, :module}])

      # Root has one group (the application) and so does the application (modules).
      assert group_labels(tree) == []
      assert tree |> LazyHTML.query("a[data-tooltip-type='Module']") |> Enum.count() == 1
    end

    test "the tree asks for a longer hint delay, so passing over rows doesn't pop hints" do
      tree = render_app_tree([{%Vertex.Module{module: Demo.Accounts}, :module}])

      assert tree |> LazyHTML.query("[data-tooltip-delay='1500'] a[data-tooltip-title]") |> Enum.count() > 0
    end

    test "a current item that is expanded marks the guide beside its own items" do
      # The application is current, and open on its modules.
      tree =
        render_app_tree([
          {%Vertex.Module{module: Demo.Accounts}, :module},
          {%Vertex.Module{module: Demo.Billing}, :module}
        ])

      active = LazyHTML.query(tree, ".tree-guide-active")
      assert Enum.count(active) == 1

      rows = active |> LazyHTML.query("li a[data-tooltip-type='Module']") |> Enum.map(&String.trim(LazyHTML.text(&1)))
      assert rows == ["Accounts", "Billing"]
    end

    test "a current item open on several groups marks the guide beside its group rows" do
      tree =
        render_app_tree([
          {%Vertex.Module{module: Demo.Accounts}, :module},
          {%Vertex.Ash.Domain{domain: Demo.Accounts}, :domain}
        ])

      active = LazyHTML.query(tree, ".tree-guide-active")
      assert Enum.count(active) == 1
      assert active |> LazyHTML.query("[id^='tree-group-'] > summary") |> Enum.count() == 2
    end

    test "a current item that is open marks only its own guide, not its siblings'" do
      app = %Vertex.Application{app: :clarity, description: "Clarity App", version: Version.parse!("0.4.0")}
      domain = %Vertex.Ash.Domain{domain: Demo.Accounts}
      other_domain = %Vertex.Ash.Domain{domain: Demo.Projects}
      resource = %Resource{resource: User}

      graph = Graph.new()
      Graph.add_vertex(graph, app, %Vertex.Root{})
      Graph.add_edge(graph, %Vertex.Root{}, app, :child)

      for d <- [domain, other_domain] do
        Graph.add_vertex(graph, d, app)
        Graph.add_edge(graph, app, d, :domain)
      end

      Graph.add_vertex(graph, resource, domain)
      Graph.add_edge(graph, domain, resource, :resource)

      {:ok, lens} = Lensmaker.get_lens_by_id("debug")

      active =
        TreeComponent
        |> render_component(
          id: "tree",
          graph: graph,
          lens: lens,
          prefix: "/",
          active_vertex: domain,
          breadcrumbs: [%Vertex.Root{}, app, domain],
          opened: MapSet.new(),
          collapsed: MapSet.new(),
          name_style: :short
        )
        |> LazyHTML.from_fragment()
        |> LazyHTML.query(".tree-guide-active")

      assert Enum.count(active) == 1
      assert active |> LazyHTML.query("a[data-tooltip-type='Resource']") |> Enum.count() == 1
      assert active |> LazyHTML.query("a[data-tooltip-type='Ash.Domain']") |> Enum.count() == 0
    end

    test "a current item without items of its own marks the guide beside it and its siblings" do
      module = %Vertex.Module{module: Demo.Accounts}
      tree = render_app_tree([{module, :module}, {%Vertex.Module{module: Demo.Billing}, :module}], module)

      active = LazyHTML.query(tree, ".tree-guide-active")
      assert Enum.count(active) == 1

      rows =
        active
        |> LazyHTML.query("li a[data-tooltip-type='Module']")
        |> Enum.map(&String.trim(LazyHTML.text(&1)))

      assert rows == ["Accounts", "Billing"]
    end

    test "every list of a node's items draws a guide, but the top level does not" do
      tree = render_app_tree([{%Vertex.Module{module: Demo.Accounts}, :module}])

      # The application sits at the top level, its module one level in.
      refute tree |> LazyHTML.query(".tree-children a[data-tooltip-type='Application']") |> Enum.any?()
      assert tree |> LazyHTML.query("ul.tree-children > li a[data-tooltip-type='Module']") |> Enum.any?()
    end

    test "a node with several groups keeps a row for each" do
      tree =
        render_app_tree([
          {%Vertex.Module{module: Demo.Accounts}, :module},
          {%Vertex.Ash.Domain{domain: Demo.Accounts}, :domain}
        ])

      assert tree |> group_labels() |> Enum.sort() == ["domain", "module"]
    end

    test "groups go in alphabetical order, with modules last" do
      tree =
        render_app_tree([
          {%Vertex.Module{module: Demo.Accounts}, :module},
          {%Router{router: DemoWeb.Router}, :router},
          {%Vertex.Ash.Domain{domain: Demo.Accounts}, :domain}
        ])

      assert group_labels(tree) == ["domain", "router", "module"]
    end
  end

  describe "long groups" do
    # An application with `count` advisories, plus `extra` edges, rendered with
    # the given opened ids.
    @spec render_long_tree(pos_integer(), [{Vertex.t(), atom()}], MapSet.t()) :: LazyHTML.t()
    defp render_long_tree(count, extra, opened \\ MapSet.new()) do
      app = %Vertex.Application{app: :clarity, description: "Clarity App", version: Version.parse!("0.4.0")}
      graph = Graph.new()
      Graph.add_vertex(graph, app, %Vertex.Root{})
      Graph.add_edge(graph, %Vertex.Root{}, app, :child)

      advisories =
        for n <- 1..count do
          %Vertex.Advisory{advisory: %Clarity.Advisory{id: "GHSA-#{n}", package: "dep"}}
        end

      for {vertex, label} <- Enum.map(advisories, &{&1, :advisory}) ++ extra do
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
        opened: opened,
        collapsed: MapSet.new(),
        name_style: :short
      )
      |> LazyHTML.from_fragment()
    end

    @spec advisory_rows(LazyHTML.t()) :: non_neg_integer()
    defp advisory_rows(tree), do: tree |> LazyHTML.query("a[data-tooltip-type='Advisory']") |> Enum.count()

    test "start closed, showing their count, and sort after short groups" do
      tree = render_long_tree(30, [{%Vertex.Module{module: Demo.Accounts}, :module}])

      assert group_labels(tree) == ["module", "advisory (30)"]
      assert advisory_rows(tree) == 0
    end

    test "short groups stay open, without a count" do
      tree = render_long_tree(3, [{%Vertex.Module{module: Demo.Accounts}, :module}])

      assert group_labels(tree) == ["advisory", "module"]
      assert advisory_rows(tree) == 3
    end

    test "keep a row of their own even as a node's only group, to open them by" do
      tree = render_long_tree(30, [])

      assert group_labels(tree) == ["advisory (30)"]
      assert advisory_rows(tree) == 0
    end

    test "open once opened, as by the user or navigating into them" do
      opened = MapSet.new(["application:clarity/advisory"])

      assert 30 |> render_long_tree([], opened) |> advisory_rows() == 30
    end
  end

  describe "the domain and resource groups" do
    # Thirty domains: more than make a long group.
    @domains for n <- 1..30,
                 do: Module.concat([Clarity.TreeComponentTest, "Domain#{n}"])

    for domain <- @domains do
      Module.create(
        domain,
        quote do
          use Ash.Domain, validate_config_inclusion?: false

          resources do
          end
        end,
        Macro.Env.location(__ENV__)
      )
    end

    test "come first and stay open, however many there are" do
      app = %Vertex.Application{app: :clarity, description: "Clarity App", version: Version.parse!("0.4.0")}
      graph = Graph.new()
      Graph.add_vertex(graph, app, %Vertex.Root{})
      Graph.add_edge(graph, %Vertex.Root{}, app, :child)

      edges =
        Enum.map(@domains, &{%Vertex.Ash.Domain{domain: &1}, :domain}) ++
          [
            {%Router{router: DemoWeb.Router}, :router},
            {%Vertex.Module{module: Demo.Accounts}, :module}
          ]

      for {vertex, label} <- edges do
        Graph.add_vertex(graph, vertex, app)
        Graph.add_edge(graph, app, vertex, label)
      end

      {:ok, lens} = Lensmaker.get_lens_by_id("debug")

      tree =
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

      assert group_labels(tree) == ["domain", "router", "module"]
      assert tree |> LazyHTML.query("a[data-tooltip-type='Domain']") |> Enum.count() == 30
    end
  end

  describe "a domain's resources" do
    # Demo.Projects's resources under its domain, rendered with `active` current.
    @spec render_projects_tree((Vertex.t() -> Vertex.t() | nil)) :: LazyHTML.t()
    defp render_projects_tree(pick_active \\ fn domain -> domain end) do
      app = %Vertex.Application{app: :clarity, description: "Clarity App", version: Version.parse!("0.4.0")}
      domain = %Vertex.Ash.Domain{domain: Demo.Projects}

      graph = Graph.new()
      Graph.add_vertex(graph, app, %Vertex.Root{})
      Graph.add_edge(graph, %Vertex.Root{}, app, :child)
      Graph.add_vertex(graph, domain, app)
      Graph.add_edge(graph, app, domain, :domain)

      resources =
        for resource <- Ash.Domain.Info.resources(Demo.Projects) do
          vertex = %Resource{resource: resource}
          Graph.add_vertex(graph, vertex, domain)
          Graph.add_edge(graph, domain, vertex, :resource)
          vertex
        end

      active = pick_active.(domain) || Enum.find(resources, &(&1.resource == Demo.Projects.Ticket.Snapshot))
      breadcrumbs = Enum.uniq([%Vertex.Root{}, app, domain, active])
      {:ok, lens} = Lensmaker.get_lens_by_id("architect")

      TreeComponent
      |> render_component(
        id: "tree",
        graph: graph,
        lens: lens,
        prefix: "/",
        active_vertex: active,
        breadcrumbs: breadcrumbs,
        opened: TreeComponent.path_ids(graph, breadcrumbs),
        collapsed: MapSet.new(),
        name_style: :short
      )
      |> LazyHTML.from_fragment()
    end

    @subgroup "[id='tree-group-ash-domain:demo-projects/resource/"

    @spec resource_rows(LazyHTML.t(), String.t()) :: [String.t()]
    defp resource_rows(tree, scope) do
      tree
      |> LazyHTML.query("#{scope} a[data-tooltip-type='Resource'] .tree-name")
      |> Enum.map(&(&1 |> LazyHTML.text() |> String.trim()))
    end

    test "are grouped by the module they're nested under, the module's resource first" do
      tree = render_projects_tree()

      assert tree |> LazyHTML.query("#{@subgroup}Sprint'][open]") |> Enum.count() == 1
      assert resource_rows(tree, "#{@subgroup}Sprint']") == ["Sprint", "Goal", "Retrospective"]
    end

    test "gather shared endings in a closed group, showing its count" do
      tree = render_projects_tree()

      assert text_of(tree, "#{@subgroup}Snapshot'] > summary") == "Snapshot (3)"
      assert tree |> LazyHTML.query("#{@subgroup}Snapshot'][open]") |> Enum.empty?()
      assert resource_rows(tree, "#{@subgroup}Snapshot']") == []
    end

    test "leave the rest ungrouped, before the groups" do
      tree = render_projects_tree()
      all = resource_rows(tree, "[id='tree-node-ash-domain:demo-projects']")

      assert Enum.take(all, 7) ==
               ["Attachment", "Comment", "Label", "Project", "Ticket", "TicketLabel", "TimeEntry"]
    end

    test "open the group of the current resource" do
      tree = render_projects_tree(fn _domain -> nil end)

      assert tree |> LazyHTML.query("#{@subgroup}Snapshot'][open]") |> Enum.count() == 1
      assert resource_rows(tree, "#{@subgroup}Snapshot']") == ["Project", "Sprint", "Ticket"]
    end
  end

  @spec text_of(LazyHTML.t(), String.t()) :: String.t()
  defp text_of(tree, selector),
    do: tree |> LazyHTML.query(selector) |> LazyHTML.text() |> String.split() |> Enum.join(" ")

  describe "row details" do
    test "a row shows its vertex's detail, muted, after its name" do
      [_bypass, read, _by_name] = PolicyInfo.policies(User)
      policy = %Vertex.Ash.Policy{policy: read, resource: User}

      row =
        [{policy, :policy}]
        |> render_app_tree()
        |> LazyHTML.query("a[data-tooltip-type='Policy']")

      assert row |> LazyHTML.query(".tree-name") |> LazyHTML.text() |> String.trim() == "read"
      assert row |> LazyHTML.query(".tree-detail") |> LazyHTML.text() |> String.trim() == "id == actor.id"
    end

    test "a row without a detail shows just its name" do
      row =
        [{%Vertex.Module{module: Demo.Accounts}, :module}]
        |> render_app_tree()
        |> LazyHTML.query("a[data-tooltip-type='Module']")

      assert row |> LazyHTML.query(".tree-detail") |> Enum.empty?()
    end
  end

  describe "revealing the current row" do
    test "the tree names the lens and current vertex for its hook to reveal" do
      [tree] = [] |> render_app_tree(nil, "documentation") |> LazyHTML.query("[phx-hook='Tree']") |> Enum.to_list()

      assert LazyHTML.attribute(tree, "data-current") == ["documentation/application:clarity"]
      assert LazyHTML.attribute(tree, "data-loading") == []
    end
  end

  describe "rows the lens has no tabs for" do
    @spec module_rows(LazyHTML.t(), String.t()) :: [String.t()]
    defp module_rows(tree, selector) do
      tree
      |> LazyHTML.query("a#{selector}[data-tooltip-type='Module']")
      |> Enum.map(&(&1 |> LazyHTML.text() |> String.trim()))
    end

    test "are greyed out, while rows with tabs are not" do
      tree =
        render_app_tree(
          [
            {%Vertex.Module{module: Demo.Accounts}, :module},
            {%Vertex.Module{module: ApiKey}, :module}
          ],
          nil,
          "documentation"
        )

      # Demo.Accounts.ApiKey sets @moduledoc false.
      assert module_rows(tree, ".tree-empty") == ["ApiKey"]
      assert module_rows(tree, ":not(.tree-empty)") == ["Accounts"]
    end

    test "are none under a lens with a tab for every vertex" do
      tree = render_app_tree([{%Vertex.Module{module: ApiKey}, :module}], nil, "graph")

      assert tree |> LazyHTML.query(".tree-empty") |> Enum.empty?()
    end
  end

  # A badge entry with `issues` of each severity beneath, named after the vertex.
  @spec badge_entry(Clarity.Status.severity(), non_neg_integer(), keyword(pos_integer())) :: map()
  defp badge_entry(severity, count, severities \\ [error: 1]) do
    issues =
      for {severity, n} <- severities, i <- 1..n do
        %{
          vertex_id: "application:dep_#{i}",
          name: "dep_#{i}",
          severity: severity,
          class: if(severity == :error, do: :security, else: :hygiene),
          message: "#{severity} #{i}"
        }
      end

    %{severity: severity, count: count, issues: Enum.take(issues, 8), severities: Map.new(severities)}
  end

  @spec render_badge(map() | nil) :: String.t()
  defp render_badge(entry) do
    {:ok, lens} = Lensmaker.get_lens_by_id("security")
    render_component(&TreeComponent.status_badge/1, entry: entry, prefix: "/", lens: lens)
  end

  describe "status_badge/1" do
    test "renders nothing without an entry" do
      html = render_badge(nil)

      refute html =~ "svg"
    end

    test "renders a pill with no count for a flagged leaf (no nested issues)" do
      html = render_badge(badge_entry(:error, 0))

      assert html =~ "rounded-full"
      assert html =~ "bg-red-100"
      # the count span (tabular-nums) is only shown when there are nested issues
      refute html =~ "tabular-nums"
    end

    test "shows the count of nested issues" do
      html = render_badge(badge_entry(:error, 3, error: 3))

      assert html =~ "bg-red-100"
      assert html =~ "tabular-nums"
      assert html =~ "3"
    end

    test "counts each severity on its own, worst first" do
      segments =
        :error
        |> badge_entry(5, info: 4, error: 1)
        |> render_badge()
        |> LazyHTML.from_fragment()
        |> LazyHTML.query("a > span")

      assert Enum.map(segments, &(&1 |> LazyHTML.text() |> String.trim())) == ["1", "4"]
      assert segments |> LazyHTML.attribute("class") |> Enum.map(&(&1 =~ "bg-red-100")) == [true, false]
      assert segments |> LazyHTML.attribute("class") |> Enum.map(&(&1 =~ "bg-blue-100")) == [false, true]
    end

    test "renders warning and info severities" do
      warning =
        render_badge(badge_entry(:warning, 1, warning: 1))

      assert warning =~ "bg-yellow-100"

      info = render_badge(badge_entry(:info, 1, info: 1))

      assert info =~ "bg-blue-100"
    end
  end

  describe "status_badge/1 link" do
    test "opens the worst issue's vertex, on the tab explaining its status class" do
      [href] =
        :error
        |> badge_entry(2, error: 1, info: 1)
        |> render_badge()
        |> LazyHTML.from_fragment()
        |> LazyHTML.query("a")
        |> LazyHTML.attribute("href")

      assert href == "/security/application:dep_1?status=security"
    end
  end

  describe "status_badge/1 hint" do
    @spec badge(map()) :: LazyHTML.t()
    defp badge(entry) do
      entry |> render_badge() |> LazyHTML.from_fragment() |> LazyHTML.query("a[aria-label]")
    end

    test "says how many issues of each severity, and lists each one" do
      badge = badge(badge_entry(:error, 2, error: 1, info: 2))

      assert LazyHTML.attribute(badge, "data-tooltip-title") == ["3 issues"]
      assert LazyHTML.attribute(badge, "data-tooltip-badges") == [~s(["1 error","2 info"])]

      assert [facts] = LazyHTML.attribute(badge, "data-tooltip-facts")

      assert JSON.decode!(facts) == [
               ["dep_1", "Error: error 1"],
               ["dep_1", "Info: info 1"],
               ["dep_2", "Info: info 2"]
             ]

      assert LazyHTML.attribute(badge, "data-tooltip-text") == []
    end

    test "says when it lists only the worst issues" do
      badge = badge(badge_entry(:warning, 12, warning: 12))

      assert LazyHTML.attribute(badge, "data-tooltip-text") == ["The worst 8 of 12:"]
      assert [facts] = LazyHTML.attribute(badge, "data-tooltip-facts")
      assert length(JSON.decode!(facts)) == 8
    end

    test "names every listed issue for assistive technology" do
      badge = badge(badge_entry(:error, 1, error: 1, warning: 1))

      assert LazyHTML.attribute(badge, "aria-label") == [
               "2 issues (1 error, 1 warning). dep_1: Error: error 1; dep_1: Warning: warning 1. Opens dep_1"
             ]
    end
  end
end
