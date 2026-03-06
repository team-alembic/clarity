defmodule Clarity.Graph do
  @moduledoc """
  Manages the graph structure.
  """

  alias Clarity.Graph.Backend
  alias Clarity.Graph.Filter
  alias Clarity.Graph.StateRef
  alias Clarity.Vertex
  alias Clarity.Vertex.Root

  @derive {Inspect, only: [:owner, :subgraph]}
  @enforce_keys [:backend, :state_ref, :owner]
  defstruct [
    :backend,
    :state_ref,
    :owner,
    subgraph: false
  ]

  @type error() :: :subgraphs_are_readonly | :not_owner | :file.posix()
  @type result() :: :ok | {:error, error()}
  @type result(inner) :: {:ok, inner} | {:error, error()}

  @typedoc """
  The Graph structure.

  It is opaque and should be manipulated only via the provided functions.
  """
  @opaque t() :: %__MODULE__{
            backend: module(),
            state_ref: :ets.tid(),
            owner: pid(),
            subgraph: boolean()
          }

  @type query_subject() :: :vertex_type | :vertex_id | {:field, atom()}

  @type query() ::
          {:and, query(), query()}
          | {:or, query(), query()}
          | {:not, query()}
          | {:==, query_subject(), term()}
          | {:!=, query_subject(), term()}
          | {:in, query_subject(), [term()]}
          | boolean()

  @doc """
  Creates a new graph.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    backend = Keyword.get(opts, :backend, Backend.configured_backend())
    backend_state = backend.new(opts)

    graph = %__MODULE__{
      backend: backend,
      state_ref: StateRef.new(backend_state),
      owner: self()
    }

    add_root_vertex(graph)
    graph
  end

  @doc """
  Deletes Graph
  """
  @spec delete(t()) :: result()
  def delete(%__MODULE__{} = graph) do
    with :ok <- check_owner(graph) do
      graph.backend.delete(get_backend_state(graph), graph.subgraph)
      StateRef.delete(graph.state_ref)

      :ok
    end
  end

  @doc """
  Transfers ownership of all ETS tables to another process.

  Used to hand over a loaded graph from the Cache process to the Server process.
  Returns an updated graph struct with the new owner.
  """
  @spec handover(t(), pid()) :: result(t())
  def handover(%__MODULE__{} = graph, pid) do
    with :ok <- check_owner(graph) do
      new_backend_state =
        graph.backend.handover(get_backend_state(graph), pid, graph.subgraph)

      put_backend_state(graph, new_backend_state)
      StateRef.give_away(graph.state_ref, pid)
      {:ok, %{graph | owner: pid}}
    end
  end

  @doc """
  Clears all vertices and edges from the graph.

  Resets graphs to empty state with root vertex.
  """
  @spec clear(t()) :: result()
  def clear(%__MODULE__{} = graph) do
    with :ok <- check_writable(graph) do
      new_backend_state = graph.backend.clear(get_backend_state(graph))
      put_backend_state(graph, new_backend_state)
      add_root_vertex(graph)
      :ok
    end
  end

  @doc """
  Adds a vertex.
  """
  @spec add_vertex(t(), Vertex.t(), Vertex.t()) :: result()
  def add_vertex(%__MODULE__{} = graph, vertex, caused_by) do
    with :ok <- check_writable(graph) do
      vertex_id = Vertex.id(vertex)
      caused_by_id = Vertex.id(caused_by)

      new_backend_state =
        graph.backend.add_vertex(
          get_backend_state(graph),
          vertex_id,
          vertex.__struct__,
          vertex,
          caused_by_id
        )

      put_backend_state(graph, new_backend_state)
      :ok
    end
  end

  @doc """
  Adds an edge between two vertices.
  """
  @spec add_edge(t(), Vertex.t(), Vertex.t(), :digraph.label()) :: result()
  def add_edge(%__MODULE__{} = graph, from_vertex, to_vertex, label) do
    with :ok <- check_writable(graph) do
      from_id = Vertex.id(from_vertex)
      to_id = Vertex.id(to_vertex)

      new_backend_state =
        graph.backend.add_edge(get_backend_state(graph), from_id, to_id, label)

      put_backend_state(graph, new_backend_state)
      :ok
    end
  end

  @doc """
  Gets the total number of vertices.
  """
  @spec vertex_count(t()) :: non_neg_integer()
  def vertex_count(%__MODULE__{} = graph) do
    graph.backend.vertex_count(get_backend_state(graph))
  end

  @doc """
  Looks up a vertex struct by its ID.
  """
  @spec get_vertex(t(), String.t()) :: Vertex.t() | nil
  def get_vertex(%__MODULE__{} = graph, vertex_id) do
    graph.backend.get_vertex(get_backend_state(graph), vertex_id)
  end

  @doc """
  Gets all vertices matching the query.

  ## Query Syntax

  Queries support complex boolean expressions using operations, operators, and fields.

  ### Operations
  - `{:and, query1, query2}` - Both queries must match
  - `{:or, query1, query2}` - Either query must match
  - `{:not, query}` - Query must not match

  ### Operators
  - `{:==, field, value}` - Field equals value
  - `{:!=, field, value}` - Field does not equal value
  - `{:in, field, values}` - Field is in list of values

  ### Fields
  - `:vertex_type` - The module of the vertex (e.g., `Application`, `Module`)
  - `:vertex_id` - The unique ID string of the vertex
  - `{:field, :field_name}` - A field within the vertex struct (e.g., `{:field, :app}`, `{:field, :module}`)

  ## Examples

      # All Application vertices
      Graph.vertices(graph, {:==, :vertex_type, Application})

      # Application OR Root vertices
      Graph.vertices(graph, {:or,
        {:==, :vertex_type, Application},
        {:==, :vertex_type, Root}
      })

      # Same as above, using :in
      Graph.vertices(graph, {:in, :vertex_type, [Application, Root]})

      # Complex: Root/Application OR (Module with specific ID)
      Graph.vertices(graph, {:or,
        {:in, :vertex_type, [Root, Application]},
        {:and, {:==, :vertex_type, Module}, {:==, :vertex_id, "module:Foo"}}
      })

      # All vertices except Root
      Graph.vertices(graph, {:not, {:==, :vertex_type, Root}})

      # Query by field value
      Graph.vertices(graph, {:and,
        {:==, :vertex_type, Application},
        {:==, {:field, :app}, :my_app}
      })

      # All vertices (default)
      Graph.vertices(graph, true)
      Graph.vertices(graph)
  """
  @spec vertices(t(), query()) :: [Vertex.t()]
  def vertices(%__MODULE__{} = graph, query \\ true) do
    graph.backend.vertices(get_backend_state(graph), query)
  end

  @doc """
  Gets all unique vertex types present in the graph.

  Returns a list of modules representing the types of vertices in the graph.
  """
  @spec available_vertex_types(t()) :: [module()]
  def available_vertex_types(%__MODULE__{} = graph) do
    graph.backend.available_vertex_types(get_backend_state(graph))
  end

  @spec vertex_ids(t(), query()) :: [String.t()]
  defp vertex_ids(%__MODULE__{} = graph, query) do
    graph.backend.vertex_ids(get_backend_state(graph), query)
  end

  @doc """
  Gets outgoing edges for a vertex.
  """
  @spec out_edges(t(), Vertex.t()) :: [:digraph.edge()]
  def out_edges(%__MODULE__{} = graph, vertex) do
    vertex_id = Vertex.id(vertex)
    graph.backend.out_edges(get_backend_state(graph), vertex_id)
  end

  @doc """
  Gets incoming edges for a vertex.
  """
  @spec in_edges(t(), Vertex.t()) :: [:digraph.edge()]
  def in_edges(%__MODULE__{} = graph, vertex) do
    vertex_id = Vertex.id(vertex)
    graph.backend.in_edges(get_backend_state(graph), vertex_id)
  end

  @doc """
  Gets all edges IDs.
  """
  @spec edges(t()) :: [:digraph.edge()]
  def edges(%__MODULE__{} = graph) do
    graph.backend.edges(get_backend_state(graph))
  end

  @doc """
  Gets edge information for a given edge ID.
  """
  @spec edge(t(), :digraph.edge()) ::
          {:digraph.edge(), Vertex.t() | nil, Vertex.t() | nil, :digraph.label()}
          | false
  def edge(%__MODULE__{} = graph, edge_id) do
    graph.backend.edge(get_backend_state(graph), edge_id)
  end

  @doc """
  Gets all vertices that are direct targets of outgoing edges from a vertex.
  """
  @spec out_neighbors(t(), Vertex.t()) :: [Vertex.t()]
  def out_neighbors(%__MODULE__{} = graph, vertex) do
    vertex_id = Vertex.id(vertex)
    graph.backend.out_neighbors(get_backend_state(graph), vertex_id)
  end

  @doc """
  Gets all vertices that are direct sources of incoming edges to a vertex.
  """
  @spec in_neighbors(t(), Vertex.t()) :: [Vertex.t()]
  def in_neighbors(%__MODULE__{} = graph, vertex) do
    vertex_id = Vertex.id(vertex)
    graph.backend.in_neighbors(get_backend_state(graph), vertex_id)
  end

  @doc """
  Gets the current update count for the graph.

  The count remains stable when no mutations occur and increases monotonically
  when the graph is modified. Use this for change detection to invalidate
  cached subgraphs.

  Do not rely on specific count values or increment amounts as the internal
  update mechanism may change.

  ## Example

      count1 = Graph.get_update_count(graph)
      # ... operations that might modify graph ...
      count2 = Graph.get_update_count(graph)

      if count2 > count1, do: # graph changed
  """
  @spec get_update_count(t()) :: pos_integer()
  def get_update_count(%__MODULE__{} = graph) do
    graph.backend.get_update_count(get_backend_state(graph))
  end

  @doc """
  Gets the total in-degree for a vertex across all edge types.
  """
  @spec in_degree(t(), Vertex.t()) :: non_neg_integer()
  def in_degree(%__MODULE__{} = graph, vertex) do
    vertex_id = Vertex.id(vertex)
    graph.backend.in_degree(get_backend_state(graph), vertex_id)
  end

  @doc """
  Gets the in-degree for a vertex for a specific edge type.
  """
  @spec in_degree(t(), Vertex.t(), :digraph.label()) :: non_neg_integer()
  def in_degree(%__MODULE__{} = graph, vertex, label) do
    vertex_id = Vertex.id(vertex)
    graph.backend.in_degree(get_backend_state(graph), vertex_id, label)
  end

  @doc """
  Gets the total out-degree for a vertex across all edge types.
  """
  @spec out_degree(t(), Vertex.t()) :: non_neg_integer()
  def out_degree(%__MODULE__{} = graph, vertex) do
    vertex_id = Vertex.id(vertex)
    graph.backend.out_degree(get_backend_state(graph), vertex_id)
  end

  @doc """
  Gets the out-degree for a vertex for a specific edge type.
  """
  @spec out_degree(t(), Vertex.t(), :digraph.label()) :: non_neg_integer()
  def out_degree(%__MODULE__{} = graph, vertex, label) do
    vertex_id = Vertex.id(vertex)
    graph.backend.out_degree(get_backend_state(graph), vertex_id, label)
  end

  @doc """
  Purges a vertex and all vertices that were caused by it.
  """
  @spec purge(t(), Vertex.t()) :: result([Vertex.t()])
  def purge(%__MODULE__{} = graph, vertex) do
    with :ok <- check_writable(graph) do
      vertex_id = Vertex.id(vertex)

      {purged_vertices, new_backend_state} =
        graph.backend.purge(get_backend_state(graph), vertex_id)

      put_backend_state(graph, new_backend_state)
      {:ok, purged_vertices}
    end
  end

  @doc """
  Gets the shortest path between the root and the vertex.
  Returns false if no path exists.
  """
  @spec breadcrumbs(t(), Vertex.t()) :: [Vertex.t()] | false
  def breadcrumbs(%__MODULE__{} = graph, vertex) do
    to_id = Vertex.id(vertex)
    graph.backend.breadcrumbs(get_backend_state(graph), to_id)
  end

  @doc """
  Gets the shortest path between two vertices.
  Returns false if no path exists.
  """
  @spec get_short_path(t(), Vertex.t(), Vertex.t()) ::
          [Vertex.t()] | false
  def get_short_path(%__MODULE__{} = graph, from_vertex, to_vertex) do
    from_id = Vertex.id(from_vertex)
    to_id = Vertex.id(to_vertex)
    graph.backend.get_short_path(get_backend_state(graph), from_id, to_id)
  end

  @doc """
  Gets the direct children of a vertex in the tree graph, grouped by edge label.

  Returns a map where keys are edge labels and values are lists of child vertices,
  sorted by vertex name for consistent ordering.

  ## Examples

      children = Graph.navigation_children(graph, root_vertex)
      # Returns: %{:application => [app1, app2], :module => [mod1]}
  """
  @spec navigation_children(t(), Vertex.t()) :: %{:digraph.label() => [Vertex.t()]}
  def navigation_children(%__MODULE__{} = graph, vertex) do
    vertex_id = Vertex.id(vertex)
    graph.backend.navigation_children(get_backend_state(graph), vertex_id)
  end

  @doc """
  Creates a filtered subgraph using a composable filter.
  Returns a new Clarity.Graph instance with the filtered vertices and edges.

  > #### Graph Memory Management {: .warning}
  >
  > Creating a subgraph will create multiple `:digraph` instances and `:ets`
  > tables. While the main graph is managed by `Clarity`, any subgraphs
  > created via this function must be explicitly deleted using `delete/1`
  > when no longer needed to free up memory.

  ## Examples

      # Single filter
      subgraph = Graph.filter(graph, Filter.within_steps(vertex, 2, 1))

      # Multiple composed filters
      filter = Filter.all([
        Filter.within_steps(vertex, 2, 1),
        Filter.reachable_from([root_vertex])
      ])
      subgraph = Graph.filter(graph, filter)
  """
  @spec filter(t(), Filter.filter() | [Filter.filter()]) :: t()
  def filter(%__MODULE__{} = graph, filters) when is_list(filters) do
    filter(graph, Filter.all(filters))
  end

  def filter(%__MODULE__{} = graph, filter) do
    query = if is_function(filter), do: filter.(graph), else: filter

    included_vertex_ids = vertex_ids(graph, query)

    new_backend_state =
      graph.backend.create_subgraph(get_backend_state(graph), included_vertex_ids)

    %__MODULE__{
      backend: graph.backend,
      state_ref: StateRef.new(new_backend_state),
      owner: self(),
      subgraph: true
    }
  end

  @doc """
  Persists a graph to disk.

  The graph must not be a subgraph.

  Returns `{:error, posix}` on file errors (e.g., `:enoent`, `:eacces`, `:enospc`).
  """
  @spec persist(t(), Path.t()) :: result()
  def persist(%__MODULE__{subgraph: true}, _path), do: {:error, :subgraphs_are_readonly}

  def persist(%__MODULE__{} = graph, path) do
    graph.backend.persist(get_backend_state(graph), path)
  end

  @doc """
  Loads a persisted graph from disk.

  > #### Security Warning {: .warning}
  >
  > Only load trusted graphs. ETS tables can contain arbitrary terms including
  > atoms and functions that may crash the VM if malicious.

  Returns `{:error, posix}` on file errors (e.g., `:enoent`, `:eacces`).
  """
  @spec load(Path.t(), keyword()) :: result(t())
  def load(path, opts \\ []) do
    backend = Keyword.get(opts, :backend, Backend.configured_backend())

    case backend.load(path) do
      {:ok, backend_state} ->
        graph = %__MODULE__{
          backend: backend,
          state_ref: StateRef.new(backend_state),
          owner: self()
        }

        {:ok, graph}

      {:error, _} = error ->
        error
    end
  end

  @spec get_backend_state(t()) :: Backend.state()
  defp get_backend_state(%__MODULE__{state_ref: ref}) do
    StateRef.get(ref)
  end

  @spec put_backend_state(t(), Backend.state()) :: true
  defp put_backend_state(%__MODULE__{state_ref: ref}, backend_state) do
    StateRef.put(ref, backend_state)
  end

  @spec add_root_vertex(t()) :: :ok
  defp add_root_vertex(graph) do
    root_vertex = %Root{}
    root_id = Vertex.id(root_vertex)

    new_backend_state =
      graph.backend.add_vertex(
        get_backend_state(graph),
        root_id,
        Root,
        root_vertex,
        root_id
      )

    put_backend_state(graph, new_backend_state)

    :ok
  end

  @spec check_owner(graph :: t()) :: :ok | {:error, error()}
  defp check_owner(%__MODULE__{owner: owner}) do
    if owner == self() do
      :ok
    else
      {:error, :not_owner}
    end
  end

  @spec check_writable(graph :: t()) :: :ok | {:error, error()}
  defp check_writable(%__MODULE__{subgraph: true}), do: {:error, :subgraphs_are_readonly}
  defp check_writable(graph), do: check_owner(graph)
end
