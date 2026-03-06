defmodule Clarity.Graph.BackendContractTest do
  use ExUnit.Case, async: true

  alias Clarity.Graph
  alias Clarity.Graph.Backend
  alias Clarity.Graph.Backend.Digraph
  alias Clarity.Graph.Filter
  alias Clarity.Vertex.Application
  alias Clarity.Vertex.Module
  alias Clarity.Vertex.Root

  defmodule RemoteStubCore do
    @moduledoc false
    @behaviour Backend

    defstruct [:digraph_state, write_buffer: [], update_count: 0]

    @impl Backend
    def new(opts \\ []), do: %__MODULE__{digraph_state: Digraph.new(opts)}

    @impl Backend
    def delete(state, subgraph), do: Digraph.delete(state.digraph_state, subgraph)

    @impl Backend
    def clear(state) do
      state = flush(state)
      digraph_state = Digraph.clear(state.digraph_state)
      %{state | digraph_state: digraph_state, update_count: state.update_count + 1}
    end

    @impl Backend
    def handover(state, pid, subgraph) do
      state = flush(state)
      digraph_state = Digraph.handover(state.digraph_state, pid, subgraph)
      %{state | digraph_state: digraph_state}
    end

    @impl Backend
    def add_vertex(state, vertex_id, vertex_type, vertex_struct, caused_by_id) do
      buffer = state.write_buffer ++ [{:add_vertex, vertex_id, vertex_type, vertex_struct, caused_by_id}]
      %{state | write_buffer: buffer, update_count: state.update_count + 1}
    end

    @impl Backend
    def add_edge(state, from_id, to_id, label) do
      buffer = state.write_buffer ++ [{:add_edge, from_id, to_id, label}]
      %{state | write_buffer: buffer, update_count: state.update_count + 1}
    end

    @impl Backend
    def purge(state, vertex_id) do
      state = flush(state)
      {purged_vertices, digraph_state} = Digraph.purge(state.digraph_state, vertex_id)
      {purged_vertices, %{state | digraph_state: digraph_state, update_count: state.update_count + 1}}
    end

    @impl Backend
    def get_vertex(state, vertex_id), do: state |> flush() |> then(&Digraph.get_vertex(&1.digraph_state, vertex_id))

    @impl Backend
    def vertex_count(state), do: state |> flush() |> then(&Digraph.vertex_count(&1.digraph_state))

    @impl Backend
    def get_update_count(state), do: state.update_count

    @impl Backend
    def out_neighbors(state, vertex_id), do: state |> flush() |> then(&Digraph.out_neighbors(&1.digraph_state, vertex_id))

    @impl Backend
    def in_neighbors(state, vertex_id), do: state |> flush() |> then(&Digraph.in_neighbors(&1.digraph_state, vertex_id))

    @impl Backend
    def out_edges(state, vertex_id), do: state |> flush() |> then(&Digraph.out_edges(&1.digraph_state, vertex_id))

    @impl Backend
    def in_edges(state, vertex_id), do: state |> flush() |> then(&Digraph.in_edges(&1.digraph_state, vertex_id))

    @impl Backend
    def edges(state), do: state |> flush() |> then(&Digraph.edges(&1.digraph_state))

    @impl Backend
    def edge(state, edge_id), do: state |> flush() |> then(&Digraph.edge(&1.digraph_state, edge_id))

    @impl Backend
    def in_degree(state, vertex_id), do: state |> flush() |> then(&Digraph.in_degree(&1.digraph_state, vertex_id))

    @impl Backend
    def in_degree(state, vertex_id, label),
      do: state |> flush() |> then(&Digraph.in_degree(&1.digraph_state, vertex_id, label))

    @impl Backend
    def out_degree(state, vertex_id), do: state |> flush() |> then(&Digraph.out_degree(&1.digraph_state, vertex_id))

    @impl Backend
    def out_degree(state, vertex_id, label),
      do: state |> flush() |> then(&Digraph.out_degree(&1.digraph_state, vertex_id, label))

    @impl Backend
    def vertices(state, query), do: state |> flush() |> then(&Digraph.vertices(&1.digraph_state, query))

    @impl Backend
    def vertex_ids(state, query), do: state |> flush() |> then(&Digraph.vertex_ids(&1.digraph_state, query))

    @impl Backend
    def available_vertex_types(state), do: state |> flush() |> then(&Digraph.available_vertex_types(&1.digraph_state))

    @impl Backend
    def breadcrumbs(state, vertex_id), do: state |> flush() |> then(&Digraph.breadcrumbs(&1.digraph_state, vertex_id))

    @impl Backend
    def get_short_path(state, from_id, to_id),
      do: state |> flush() |> then(&Digraph.get_short_path(&1.digraph_state, from_id, to_id))

    @impl Backend
    def navigation_children(state, vertex_id),
      do: state |> flush() |> then(&Digraph.navigation_children(&1.digraph_state, vertex_id))

    @impl Backend
    def vertices_within_steps(state, vertex_id, max_out, max_in),
      do: state |> flush() |> then(&Digraph.vertices_within_steps(&1.digraph_state, vertex_id, max_out, max_in))

    @impl Backend
    def reachable_from(state, source_vertex_ids),
      do: state |> flush() |> then(&Digraph.reachable_from(&1.digraph_state, source_vertex_ids))

    @impl Backend
    def create_subgraph(state, vertex_ids) do
      state = flush(state)
      %{state | digraph_state: Digraph.create_subgraph(state.digraph_state, vertex_ids)}
    end

    @impl Backend
    def persist(state, path), do: state |> flush() |> then(&Digraph.persist(&1.digraph_state, path))

    @impl Backend
    def load(path, opts \\ []) do
      with {:ok, digraph_state} <- Digraph.load(path, opts) do
        {:ok, %__MODULE__{digraph_state: digraph_state, update_count: Digraph.get_update_count(digraph_state)}}
      end
    end

    defp flush(%{write_buffer: []} = state), do: state

    defp flush(state) do
      digraph_state =
        Enum.reduce(state.write_buffer, state.digraph_state, fn
          {:add_vertex, vertex_id, vertex_type, vertex_struct, caused_by_id}, acc ->
            Digraph.add_vertex(acc, vertex_id, vertex_type, vertex_struct, caused_by_id)

          {:add_edge, from_id, to_id, label}, acc ->
            if existing_edge?(acc, from_id, to_id, label) do
              acc
            else
              Digraph.add_edge(acc, from_id, to_id, label)
            end
        end)

      %{state | digraph_state: digraph_state, write_buffer: []}
    end

    defp existing_edge?(digraph_state, from_id, to_id, label) do
      digraph_state
      |> Digraph.out_edges(from_id)
      |> Enum.any?(fn edge_id ->
        case Digraph.edge(digraph_state, edge_id) do
          {^edge_id, _from_vertex, to_vertex, ^label} ->
            to_vertex != nil and Clarity.Vertex.id(to_vertex) == to_id

          _ ->
            false
        end
      end)
    end
  end

  defmodule Neo4jStub do
    @moduledoc false
    @behaviour Backend

    alias Clarity.Graph.BackendContractTest.RemoteStubCore

    for {name, arity} <- [
          {:new, 1},
          {:delete, 2},
          {:clear, 1},
          {:handover, 3},
          {:add_vertex, 5},
          {:add_edge, 4},
          {:purge, 2},
          {:get_vertex, 2},
          {:vertex_count, 1},
          {:get_update_count, 1},
          {:out_neighbors, 2},
          {:in_neighbors, 2},
          {:out_edges, 2},
          {:in_edges, 2},
          {:edges, 1},
          {:edge, 2},
          {:in_degree, 2},
          {:in_degree, 3},
          {:out_degree, 2},
          {:out_degree, 3},
          {:vertices, 2},
          {:vertex_ids, 2},
          {:available_vertex_types, 1},
          {:breadcrumbs, 2},
          {:get_short_path, 3},
          {:navigation_children, 2},
          {:vertices_within_steps, 4},
          {:reachable_from, 2},
          {:create_subgraph, 2},
          {:persist, 2},
          {:load, 2}
        ] do
      args = Macro.generate_arguments(arity, __MODULE__)
      defdelegate unquote(name)(unquote_splicing(args)), to: RemoteStubCore
    end
  end

  defmodule ArcadeDBStub do
    @moduledoc false
    @behaviour Backend

    alias Clarity.Graph.BackendContractTest.RemoteStubCore

    for {name, arity} <- [
          {:new, 1},
          {:delete, 2},
          {:clear, 1},
          {:handover, 3},
          {:add_vertex, 5},
          {:add_edge, 4},
          {:purge, 2},
          {:get_vertex, 2},
          {:vertex_count, 1},
          {:get_update_count, 1},
          {:out_neighbors, 2},
          {:in_neighbors, 2},
          {:out_edges, 2},
          {:in_edges, 2},
          {:edges, 1},
          {:edge, 2},
          {:in_degree, 2},
          {:in_degree, 3},
          {:out_degree, 2},
          {:out_degree, 3},
          {:vertices, 2},
          {:vertex_ids, 2},
          {:available_vertex_types, 1},
          {:breadcrumbs, 2},
          {:get_short_path, 3},
          {:navigation_children, 2},
          {:vertices_within_steps, 4},
          {:reachable_from, 2},
          {:create_subgraph, 2},
          {:persist, 2},
          {:load, 2}
        ] do
      args = Macro.generate_arguments(arity, __MODULE__)
      defdelegate unquote(name)(unquote_splicing(args)), to: RemoteStubCore
    end
  end

  @backends [Digraph, Neo4jStub, ArcadeDBStub]

  for backend <- @backends do
    describe "backend contract #{inspect(backend)}" do
      test "supports core graph mutations and queries" do
        graph = Graph.new(backend: unquote(backend))

        app = %Application{app: :contract_app, description: "Contract App", version: "1.0.0"}
        mod = %Module{module: ContractModule}

        assert :ok = Graph.add_vertex(graph, app, %Root{})
        assert :ok = Graph.add_vertex(graph, mod, app)
        assert :ok = Graph.add_edge(graph, %Root{}, app, :application)
        assert :ok = Graph.add_edge(graph, app, mod, :module)

        assert Graph.vertex_count(graph) == 3
        assert Graph.get_vertex(graph, "root") == %Root{}
        assert Graph.out_degree(graph, app, :module) == 1
        assert Graph.in_degree(graph, mod, :module) == 1

        assert :ok = Graph.delete(graph)
      end

      test "supports filter subgraphs and deleting subgraphs safely" do
        graph = Graph.new(backend: unquote(backend))

        app = %Application{app: :contract_app2, description: "Contract App", version: "1.0.0"}
        mod = %Module{module: ContractModule2}

        Graph.add_vertex(graph, app, %Root{})
        Graph.add_vertex(graph, mod, app)
        Graph.add_edge(graph, %Root{}, app, :application)
        Graph.add_edge(graph, app, mod, :module)

        subgraph = Graph.filter(graph, Filter.within_steps(%Root{}, 1, 0))

        assert Graph.vertex_count(subgraph) == 2
        assert :ok = Graph.delete(subgraph)
        assert Graph.vertex_count(graph) == 3

        assert :ok = Graph.delete(graph)
      end

      test "tracks update_count for write operations" do
        graph = Graph.new(backend: unquote(backend))

        before_count = Graph.get_update_count(graph)

        app = %Application{app: :contract_app3, description: "Contract App", version: "1.0.0"}
        Graph.add_vertex(graph, app, %Root{})

        assert Graph.get_update_count(graph) > before_count

        assert :ok = Graph.delete(graph)
      end
    end
  end
end
