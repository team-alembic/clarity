defmodule AshAtlas do
  @moduledoc false

  use Agent

  @type tree() :: %{
          node: :digraph.vertex(),
          children: %{
            optional(:digraph.label()) => [tree()]
          }
        }

  @type t() :: %__MODULE__{
          graph: :digraph.graph(),
          root: AshAtlas.Vertex.t(),
          tree: tree(),
          vertices: %{String.t() => AshAtlas.Vertex.t()}
        }

  @enforce_keys [:graph, :root, :tree, :vertices]
  defstruct [:graph, :root, :tree, :vertices]

  @doc false
  @spec start_link(opts :: GenServer.options()) :: Agent.on_start()
  def start_link(opts \\ []) do
    opts = Keyword.put_new(opts, :name, __MODULE__)

    Agent.start_link(&introspect/0, opts)
  end

  @spec get(name :: Agent.agent()) :: t()
  def get(name \\ __MODULE__), do: Agent.get(name, & &1)

  @spec update(name :: Agent.agent()) :: t()
  def update(name \\ __MODULE__) do
    Agent.get_and_update(name, fn _state ->
      atlas = introspect()
      {atlas, atlas}
    end)
  end

  @spec introspect() :: t()
  def introspect do
    graph = AshAtlas.Introspector.introspect(:digraph.new())

    vertices =
      for vertex <- :digraph.vertices(graph),
          into: %{},
          do: {AshAtlas.Vertex.unique_id(vertex), vertex}

    root_vertex = Map.fetch!(vertices, "root")

    tree = AshAtlas.GraphUtil.graph_to_tree(graph, root_vertex)

    %__MODULE__{graph: graph, root: root_vertex, tree: tree, vertices: vertices}
  end
end
