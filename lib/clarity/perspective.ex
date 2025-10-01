defmodule Clarity.Perspective do
  @moduledoc """
  Stateful Agent that manages lens views, filtered subgraphs, and current vertex context.

  Provides lazy subgraph computation and automatic cache invalidation when the lens,
  vertex, or underlying graph changes.
      
      # Install different lens by ID
      :ok = Perspective.install_lens(pid, "architect")
      
      # Get current state
      %Lens{id: "architect"} = Perspective.get_current_lens(pid)
      %Root{} = Perspective.get_current_vertex(pid)
      
      # Set current vertex (returns error if not found)
      :ok = Perspective.set_current_vertex(pid, "some_vertex")
      {:error, :vertex_not_found} = Perspective.set_current_vertex(pid, "nonexistent")
      
      # Get filtered subgraph (computed lazily)
      subgraph = Perspective.get_subgraph(pid)
      
      # Get intro vertex from current lens
      intro_vertex = Perspective.get_intro_vertex(pid)  # may be nil
      
      # Get content for vertex
      content_list = Perspective.get_content_for_vertex(pid, "some_vertex")

  ## Configuration

  Default lens configuration is managed by `Clarity.Config`. See the documentation
  for `Clarity.Config` for detailed configuration options and examples.
  """

  use Agent

  alias Clarity.Graph
  alias Clarity.Graph.Tree
  alias Clarity.Perspective.Lens
  alias Clarity.Perspective.Registry
  alias Clarity.Vertex
  alias Clarity.Vertex.Content
  alias Clarity.Vertex.Root

  @type zoom() :: {non_neg_integer(), non_neg_integer()}

  @opaque t() :: %__MODULE__{
            graph: Graph.t(),
            current_lens: Lens.t(),
            current_vertex: Vertex.t(),
            cached_subgraph: Graph.t() | nil,
            cache_params:
              %{lens_id: String.t(), vertex_id: String.t(), update_count: pos_integer()} | nil,
            cached_tree: Tree.t() | nil,
            cached_breadcrumbs: [Vertex.t()] | nil,
            zoom_level: zoom(),
            cached_zoom_subgraph: Graph.t() | nil
          }

  @enforce_keys [:graph, :current_lens]
  defstruct [
    :graph,
    :current_lens,
    current_vertex: %Root{},
    cached_subgraph: nil,
    cache_params: nil,
    cached_tree: nil,
    cached_breadcrumbs: nil,
    zoom_level: {2, 1},
    cached_zoom_subgraph: nil,
    zoom_cache_params: nil
  ]

  @type error() ::
          :lens_not_found
          | :vertex_not_found
          | {:lens_error, term()}
          | {:graph_error, term()}

  @type result(type) :: {:ok, type} | {:error, error()}

  @doc """
  Starts the Perspective Agent with a graph and auto-installs the default lens.
  """
  @spec start_link(Graph.t()) :: Agent.on_start()
  def start_link(graph) do
    default_lens_id = Clarity.Config.fetch_default_perspective_lens!()
    {:ok, lens} = resolve_lens(default_lens_id)

    initial_vertex = lens.intro_vertex.(graph) || %Root{}

    initial_state = %__MODULE__{
      graph: graph,
      current_lens: lens,
      current_vertex: initial_vertex
    }

    Agent.start_link(fn -> initial_state end)
  end

  @doc """
  Installs a lens in the agent.

  Accepts either a lens ID (resolved via Registry) or a lens struct directly.
  """
  @spec install_lens(Agent.agent(), String.t() | Lens.t()) :: {:ok, Lens.t()} | {:error, error()}
  def install_lens(agent, lens_id_or_lens) do
    with {:ok, lens} <- resolve_lens(lens_id_or_lens),
         :ok <- Agent.update(agent, &%{&1 | current_lens: lens}) do
      {:ok, lens}
    end
  end

  @doc """
  Gets the currently installed lens.
  """
  @spec get_current_lens(Agent.agent()) :: Lens.t()
  def get_current_lens(agent) do
    Agent.get(agent, & &1.current_lens)
  end

  @doc """
  Sets the current vertex being viewed.

  Accepts either a vertex ID or a vertex struct.
  """
  @spec set_current_vertex(Agent.agent(), String.t() | Vertex.t()) ::
          {:ok, Vertex.t()} | {:error, error()}
  def set_current_vertex(agent, vertex_id_or_vertex) do
    vertex_id = extract_vertex_id(vertex_id_or_vertex)

    Agent.get_and_update(agent, fn state ->
      case Graph.get_vertex(state.graph, vertex_id) do
        nil ->
          {{:error, :vertex_not_found}, state}

        vertex ->
          new_state = %{state | current_vertex: vertex}
          {{:ok, vertex}, new_state}
      end
    end)
  end

  @doc """
  Gets the current vertex.
  """
  @spec get_current_vertex(Agent.agent()) :: Vertex.t()
  def get_current_vertex(agent) do
    Agent.get(agent, & &1.current_vertex)
  end

  @regular_cache_params [:lens_id, :vertex_id, :update_count]
  @zoom_cache_params [:zoom_level | @regular_cache_params]
  @spec invalidate_outdated_caches(t()) :: t()
  defp invalidate_outdated_caches(%__MODULE__{current_lens: lens, current_vertex: vertex} = state) do
    # Compute current cache parameters
    vertex_id = Vertex.unique_id(vertex)
    update_count = Graph.get_update_count(state.graph)

    current_params = %{
      lens_id: lens.id,
      vertex_id: vertex_id,
      update_count: update_count,
      zoom_level: state.zoom_level
    }

    cond do
      Map.take(current_params, @regular_cache_params) !=
          Map.take(state.cache_params || %{}, @regular_cache_params) ->
        if state.cached_subgraph, do: Graph.delete(state.cached_subgraph)
        if state.cached_zoom_subgraph, do: Graph.delete(state.cached_zoom_subgraph)

        %{
          state
          | cache_params: current_params,
            cached_subgraph: nil,
            cached_tree: nil,
            cached_breadcrumbs: nil,
            cached_zoom_subgraph: nil
        }

      Map.take(current_params, @zoom_cache_params) !=
          Map.take(state.cache_params || %{}, @zoom_cache_params) ->
        if state.cached_zoom_subgraph, do: Graph.delete(state.cached_zoom_subgraph)

        %{
          state
          | cache_params: current_params,
            cached_zoom_subgraph: nil
        }

      true ->
        state
    end
  end

  @doc """
  Gets the filtered subgraph for the current lens and vertex.

  Computes the subgraph lazily, including the current vertex, breadcrumb path,
  and all vertices that pass the lens filter.
  """
  @spec get_subgraph(Agent.agent()) :: Graph.t()
  def get_subgraph(agent) do
    Agent.get_and_update(agent, &handle_subgraph_request/1)
  end

  @spec handle_subgraph_request(t()) :: {Graph.t(), t()}
  defp handle_subgraph_request(state) do
    state = invalidate_outdated_caches(state)

    case state.cached_subgraph do
      nil ->
        # Create new subgraph
        subgraph =
          compute_subgraph(
            state.graph,
            state.current_lens,
            state.current_vertex
          )

        state = %{state | cached_subgraph: subgraph}
        {subgraph, state}

      cached_subgraph ->
        {cached_subgraph, state}
    end
  end

  @doc """
  Gets the tree structure for navigation, computed lazily from the filtered subgraph.
  """
  @spec get_tree(Agent.agent()) :: Tree.t()
  def get_tree(agent) do
    Agent.get_and_update(agent, &handle_tree_request/1)
  end

  @spec handle_tree_request(t()) :: {Tree.t(), t()}
  defp handle_tree_request(state) do
    state = invalidate_outdated_caches(state)
    {subgraph, state} = handle_subgraph_request(state)

    case state.cached_tree do
      nil ->
        tree = Graph.to_tree(subgraph)
        state = %{state | cached_tree: tree}
        {tree, state}

      cached_tree ->
        {cached_tree, state}
    end
  end

  @doc """
  Gets the breadcrumb path from root to current vertex, computed lazily.
  """
  @spec get_breadcrumbs(Agent.agent()) :: [Vertex.t()]
  def get_breadcrumbs(agent) do
    Agent.get_and_update(agent, &handle_breadcrumbs_request/1)
  end

  @spec handle_breadcrumbs_request(t()) :: {[Vertex.t()], t()}
  defp handle_breadcrumbs_request(state) do
    state = invalidate_outdated_caches(state)
    {subgraph, state} = handle_subgraph_request(state)

    case state.cached_breadcrumbs do
      nil ->
        breadcrumbs = Graph.breadcrumbs(subgraph, state.current_vertex) || [state.current_vertex]
        state = %{state | cached_breadcrumbs: breadcrumbs}
        {breadcrumbs, state}

      cached_breadcrumbs ->
        {cached_breadcrumbs, state}
    end
  end

  @doc """
  Gets the intro vertex from the current lens (may be nil).
  """
  @spec get_intro_vertex(Agent.agent()) :: Vertex.t() | nil
  def get_intro_vertex(agent) do
    Agent.get(agent, fn %__MODULE__{
                          current_lens: %Lens{intro_vertex: intro_vertex_fn},
                          graph: graph
                        } ->
      intro_vertex_fn.(graph)
    end)
  end

  @doc """
  Gets the content list for the current vertex, with "graph" content prepended.
  """
  @spec get_contents(Agent.agent()) :: [Content.t()]
  def get_contents(agent) do
    Agent.get_and_update(agent, &handle_contents_request/1)
  end

  @doc """
  Gets a specific content vertex by ID for the current vertex context.
  """
  @spec get_content(Agent.agent(), String.t()) ::
          {:ok, Content.t()} | {:error, :content_not_found}
  def get_content(agent, content_id) do
    contents = get_contents(agent)

    case Enum.find(contents, fn content -> content.id == content_id end) do
      nil -> {:error, :content_not_found}
      content -> {:ok, content}
    end
  end

  @spec handle_contents_request(t()) :: {[Content.t()], t()}
  defp handle_contents_request(state) do
    {subgraph, state} = handle_subgraph_request(state)
    pid = self()

    graph_content = %Content{
      id: "graph",
      name: "Graph Navigation",
      content:
        {:viz,
         fn %{theme: theme} ->
           Graph.DOT.to_dot(
             get_zoom_subgraph(pid),
             theme: theme,
             highlight: state.current_vertex
           )
         end}
    }

    contents =
      subgraph
      |> Graph.out_edges(state.current_vertex)
      |> Enum.map(&Graph.edge(subgraph, &1))
      |> Enum.filter(fn {_, _, _, label} -> label == :content end)
      |> Enum.map(fn {_, _, to_vertex, _} -> to_vertex end)
      |> then(&[graph_content | &1])
      |> Enum.sort(state.current_lens.content_sorter)

    {contents, state}
  end

  @doc """
  Sets the zoom level for graph visualization.

  The zoom level determines how many steps to include when filtering
  the subgraph for graph content visualization. This does not affect
  tree or breadcrumb navigation.

  ## Parameters

  - `agent` - The agent process
  - `zoom` - Tuple of {max_outgoing_steps, max_incoming_steps}

  ## Returns

  - `:ok` - Zoom level set successfully

  ## Examples

      :ok = Perspective.set_zoom(agent, {3, 2})
      :ok = Perspective.set_zoom(agent, {1, 1})
  """
  @spec set_zoom(Agent.agent(), zoom()) :: :ok
  def set_zoom(agent, zoom) do
    Agent.update(agent, &%{&1 | zoom_level: zoom})
  end

  @doc """
  Gets the current zoom level.

  ## Parameters

  - `agent` - The agent process

  ## Returns

  - Current zoom level as {max_outgoing_steps, max_incoming_steps}

  ## Examples

      {2, 1} = Perspective.get_zoom(agent)
  """
  @spec get_zoom(Agent.agent()) :: zoom()
  def get_zoom(agent) do
    Agent.get(agent, & &1.zoom_level)
  end

  @doc """
  Gets the zoom-filtered subgraph for graph visualization.

  Computes a subgraph that includes the current vertex and all vertices
  within the specified zoom steps, filtered by the current lens and
  including the breadcrumb path. This is intended for graph content
  visualization and is separate from tree/breadcrumb navigation.

  ## Parameters

  - `agent` - The agent process

  ## Returns

  - Zoom-filtered subgraph

  ## Examples

      subgraph = Perspective.get_zoom_subgraph(agent)
      # Remember to call Graph.delete(subgraph) when done
  """
  @spec get_zoom_subgraph(Agent.agent()) :: Graph.t()
  def get_zoom_subgraph(agent) do
    Agent.get_and_update(agent, &handle_zoom_subgraph_request/1)
  end

  @spec handle_zoom_subgraph_request(t()) :: {Graph.t(), t()}
  defp handle_zoom_subgraph_request(state) do
    state = invalidate_outdated_caches(state)
    {subgraph, state} = handle_subgraph_request(state)

    case state.cached_zoom_subgraph do
      nil ->
        {outgoing_steps, incoming_steps} = state.zoom_level

        zoom_subgraph =
          Graph.filter(
            subgraph,
            Graph.Filter.within_steps(state.current_vertex, outgoing_steps, incoming_steps)
          )

        state = %{state | cached_zoom_subgraph: zoom_subgraph}
        {zoom_subgraph, state}

      cached_zoom_subgraph ->
        {cached_zoom_subgraph, state}
    end
  end

  @spec resolve_lens(String.t() | Lens.t()) :: result(Lens.t())
  defp resolve_lens(lens_id) when is_binary(lens_id) do
    case Registry.get_lens_by_id(lens_id) do
      {:ok, lens} -> {:ok, lens}
      {:error, reason} -> {:error, reason}
    end
  end

  defp resolve_lens(%Lens{} = lens), do: {:ok, lens}

  @spec extract_vertex_id(String.t() | Vertex.t()) :: String.t()
  defp extract_vertex_id(vertex_id) when is_binary(vertex_id), do: vertex_id
  defp extract_vertex_id(vertex), do: Vertex.unique_id(vertex)

  @spec compute_subgraph(Graph.t(), Lens.t(), Vertex.t()) :: Graph.t()
  defp compute_subgraph(graph, lens, vertex) do
    context_filter =
      Graph.Filter.any([
        lens.filter,
        fn graph ->
          breadcrumbs =
            graph
            |> Graph.breadcrumbs(vertex)
            |> Kernel.||([vertex])
            |> MapSet.new()

          &MapSet.member?(breadcrumbs, &1)
        end
      ])

    Graph.filter(graph, context_filter)
  end
end
