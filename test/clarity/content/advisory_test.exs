defmodule Clarity.Content.AdvisoryTest do
  # async: false — installs the globally-named Clarity.Advisory.Source ETS table.
  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest

  alias Clarity.Advisory.Source
  alias Clarity.Content
  alias Clarity.Graph
  alias Clarity.Perspective.Lensmaker.Security
  alias Clarity.Vertex
  alias Clarity.Vertex.Root

  setup do
    :ets.new(Source, [:named_table, :set, :public])

    # The project depends on phoenix, which depends on plug; and on jason.
    graph = Graph.new()
    project = app(graph, :project, "0.1.0")
    phoenix = app(graph, :phoenix, "1.7.0")
    plug = app(graph, :plug, "1.14.0")
    jason = app(graph, :jason, "1.4.0")

    Graph.add_edge(graph, project, phoenix, :dependency)
    Graph.add_edge(graph, project, jason, :dependency)
    Graph.add_edge(graph, phoenix, plug, :dependency)

    {:ok, graph: graph, project: project, phoenix: phoenix, plug: plug}
  end

  @spec app(Graph.t(), atom(), String.t()) :: Vertex.Application.t()
  defp app(graph, name, version) do
    vertex = %Vertex.Application{app: name, description: "", version: version}
    Graph.add_vertex(graph, vertex, %Root{})
    vertex
  end

  @spec render_advisories(Graph.t(), Vertex.t()) :: LazyHTML.t()
  defp render_advisories(graph, vertex) do
    Content.Advisory
    |> render_component(
      id: "content-view",
      vertex: vertex,
      lens: Security.make_lens(),
      prefix: "/c",
      graph: graph
    )
    |> LazyHTML.from_fragment()
  end

  @spec text(LazyHTML.t()) :: String.t()
  defp text(html), do: html |> LazyHTML.text() |> String.split() |> Enum.join(" ")

  describe "an application's advisories" do
    setup do
      :ets.new(Clarity.Dependency.Registry, [:named_table, :set, :public])
      :ok
    end

    test "sum up its dependencies', through the ones that pull them in, with their versions", %{
      graph: graph,
      project: project,
      plug: plug
    } do
      :ets.insert(
        Source,
        {{:package, "plug"},
         [
           %Clarity.Advisory{
             id: "EEF-CVE-2026-0001",
             package: "plug",
             severity: "HIGH",
             ranges: [%{"events" => [%{"introduced" => "0"}, %{"fixed" => "1.15.0"}]}]
           }
         ]}
      )

      :ets.insert(Clarity.Dependency.Registry, [
        {{:package, "plug"}, %{latest: "1.16.0", retired: []}},
        {{:package, "jason"}, %{latest: "1.5.0", retired: []}},
        {{:package, "phoenix"}, %{latest: "1.7.0", retired: []}}
      ])

      html = render_advisories(graph, project)

      assert text(html) =~ "project isn't installed from Hex, so it has no advisories of its own."

      assert text(html) =~
               "Of its 3 dependencies, 1 has a known advisory and 1 is behind its latest release."

      # Worst first: the vulnerable dependency, then the outdated one; phoenix
      # is up to date, so isn't listed.
      assert [vulnerable, outdated] = html |> LazyHTML.query("tbody tr") |> Enum.to_list()

      assert text(vulnerable) ==
               "plug 1.14.0 1.16.0 Vulnerable EEF-CVE-2026-0001 · CVE-2026-0001 · fixed in 1.15.0"

      assert text(outdated) == "jason 1.4.0 1.5.0 Outdated —"

      assert vulnerable |> LazyHTML.query("a") |> LazyHTML.attribute("href") == [
               "/c/security/#{Vertex.id(plug)}",
               "/c/security/advisory:EEF-CVE-2026-0001",
               "https://cna.erlef.org/cves/CVE-2026-0001.html"
             ]
    end

    test "say when its dependencies have nothing to update for", %{graph: graph, phoenix: phoenix} do
      assert text(render_advisories(graph, phoenix)) =~
               "Its 1 dependency has no known advisory and is on its latest release."
    end

    test "say nothing of dependencies for an application without any", %{graph: graph, plug: plug} do
      refute text(render_advisories(graph, plug)) =~ "Its Dependencies"
    end
  end

  describe "an advisory" do
    test "links its CVE to the record at the CNA that assigned it, and GitHub's id to GitHub" do
      advisory = %Clarity.Advisory{
        id: "EEF-CVE-2026-0001",
        package: "plug",
        aliases: ["CVE-2026-0001", "GHSA-aaaa-bbbb-cccc"]
      }

      links =
        Graph.new()
        |> render_advisories(%Vertex.Advisory{advisory: advisory})
        |> LazyHTML.query("a")
        |> Enum.map(&{text(&1), &1 |> LazyHTML.attribute("href") |> hd()})

      assert {"CVE-2026-0001", "https://cna.erlef.org/cves/CVE-2026-0001.html"} in links
      assert {"GHSA-aaaa-bbbb-cccc", "https://github.com/advisories/GHSA-aaaa-bbbb-cccc"} in links
    end
  end
end
