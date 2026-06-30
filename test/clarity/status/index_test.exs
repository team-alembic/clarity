defmodule Clarity.Status.IndexTest do
  # async: false — registers a provider in the global :clarity_status_providers env.
  use ExUnit.Case, async: false

  alias Clarity.Graph
  alias Clarity.Perspective.Lens
  alias Clarity.Status
  alias Clarity.Status.Index
  alias Clarity.Status.Provider
  alias Clarity.Vertex
  alias Clarity.Vertex.Root

  defmodule TestProvider do
    @moduledoc false
    @behaviour Provider

    @impl Provider
    def statuses(%Vertex.Application{app: :err}, _graph),
      do: [%Status{severity: :error, class: :security, message: "e", source: __MODULE__}]

    def statuses(%Vertex.Application{app: :info}, _graph),
      do: [%Status{severity: :info, class: :hygiene, message: "i", source: __MODULE__}]

    def statuses(%Vertex.Application{app: :other}, _graph),
      do: [%Status{severity: :error, class: :other, message: "o", source: __MODULE__}]

    def statuses(_vertex, _graph), do: []
  end

  setup do
    original = Application.fetch_env(:clarity, :clarity_status_providers)
    Application.put_env(:clarity, :clarity_status_providers, [TestProvider])

    on_exit(fn ->
      case original do
        {:ok, value} -> Application.put_env(:clarity, :clarity_status_providers, value)
        :error -> Application.delete_env(:clarity, :clarity_status_providers)
      end
    end)

    graph = Graph.new()
    root = %Root{}
    parent = %Vertex.Application{app: :parent, description: "Parent", version: "1.0.0"}
    err = %Vertex.Application{app: :err, description: "Err", version: "1.0.0"}
    info = %Vertex.Application{app: :info, description: "Info", version: "1.0.0"}
    other = %Vertex.Application{app: :other, description: "Other", version: "1.0.0"}

    for v <- [parent, err, info, other], do: Graph.add_vertex(graph, v, root)
    Graph.add_edge(graph, root, parent, :application)
    Graph.add_edge(graph, parent, err, :dependency)
    Graph.add_edge(graph, parent, info, :dependency)
    Graph.add_edge(graph, parent, other, :dependency)

    {:ok, graph: graph, vertices: %{root: root, parent: parent, err: err, info: info, other: other}}
  end

  defp lens(status_filter) do
    %Lens{id: "t", name: "T", icon: fn -> nil end, filter: true, status_filter: status_filter}
  end

  describe "build/2" do
    test "rolls up worst severity and a count of flagged descendants", %{graph: graph, vertices: v} do
      index = Index.build(graph, lens(&(&1.class in [:security, :hygiene])))

      assert index[Vertex.id(v.err)] == %{severity: :error, count: 1}
      assert index[Vertex.id(v.info)] == %{severity: :info, count: 1}
      # parent itself isn't flagged; rolls up err (:error) + info (:info) = error, count 2
      assert index[Vertex.id(v.parent)] == %{severity: :error, count: 2}
      assert index[Vertex.id(v.root)] == %{severity: :error, count: 2}
    end

    test "counts the vertex itself when it is flagged", %{graph: graph, vertices: v} do
      # :other is flagged but its class is filtered out below; flag-and-count uses err/info only
      index = Index.build(graph, lens(&(&1.class in [:security, :hygiene])))

      # err is a flagged leaf: count includes itself
      assert index[Vertex.id(v.err)].count == 1
    end

    test "only rolls up statuses the lens surfaces", %{graph: graph, vertices: v} do
      index = Index.build(graph, lens(&(&1.class == :security)))

      assert index[Vertex.id(v.err)] == %{severity: :error, count: 1}
      # :info is :hygiene, filtered out
      refute Map.has_key?(index, Vertex.id(v.info))
      # :other is :other class, filtered out
      refute Map.has_key?(index, Vertex.id(v.other))
      # parent now rolls up only err
      assert index[Vertex.id(v.parent)] == %{severity: :error, count: 1}
    end

    test "is empty when the lens surfaces nothing", %{graph: graph} do
      assert Index.build(graph, lens(&Lens.reject_all_statuses/1)) == %{}
    end
  end

  describe "vertex_classes/3" do
    test "groups a vertex's own statuses by class to the worst severity",
         %{graph: graph, vertices: v} do
      lens = lens(&(&1.class in [:security, :hygiene]))

      assert Index.vertex_classes(graph, v.err, lens) == %{security: :error}
      assert Index.vertex_classes(graph, v.info, lens) == %{hygiene: :info}
      # parent has no own status; this is not a roll-up
      assert Index.vertex_classes(graph, v.parent, lens) == %{}
    end

    test "excludes classes the lens does not surface", %{graph: graph, vertices: v} do
      lens = lens(&(&1.class == :security))

      assert Index.vertex_classes(graph, v.err, lens) == %{security: :error}
      assert Index.vertex_classes(graph, v.info, lens) == %{}
      assert Index.vertex_classes(graph, v.other, lens) == %{}
    end
  end
end
