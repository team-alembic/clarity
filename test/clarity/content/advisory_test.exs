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
    test "sums up those of its dependencies, through the ones that pull them in", %{
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

      html = render_advisories(graph, project)

      assert text(html) =~ "No known advisories for project 0.1.0."
      assert text(html) =~ "1 advisory in 1 of its 3 dependencies."

      assert [row] = html |> LazyHTML.query("tbody tr") |> Enum.to_list()
      assert text(row) == "plug 1.14.0 EEF-CVE-2026-0001 HIGH 1.15.0"

      assert row |> LazyHTML.query("a") |> LazyHTML.attribute("href") == [
               "/c/security/#{Vertex.id(plug)}",
               "/c/security/advisory:EEF-CVE-2026-0001"
             ]
    end

    test "says when none of its dependencies has one", %{graph: graph, phoenix: phoenix} do
      assert text(render_advisories(graph, phoenix)) =~ "No known advisories in its 1 dependency."
    end

    test "says nothing of dependencies for an application without any", %{graph: graph, plug: plug} do
      refute text(render_advisories(graph, plug)) =~ "In Its Dependencies"
    end
  end
end
