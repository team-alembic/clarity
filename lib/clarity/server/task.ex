defmodule Clarity.Server.Task do
  @moduledoc false

  alias Clarity.Server.Queue

  @type t :: %__MODULE__{
          id: reference(),
          vertex: Clarity.Vertex.t(),
          introspector: module(),
          graph: Clarity.Graph.t(),
          lane: Queue.lane(),
          requeue_count: non_neg_integer(),
          ran_at: non_neg_integer() | nil
        }

  defstruct [
    :id,
    :vertex,
    :introspector,
    :graph,
    lane: :model,
    requeue_count: 0,
    # The graph's update count when the task last started: waiting, it runs
    # again once the graph has changed since.
    ran_at: nil
  ]

  @doc """
  Creates a new introspection task for a vertex, to run in `lane`.
  """
  @spec new_introspection(Clarity.Vertex.t(), module(), Clarity.Graph.t()) :: t()
  @spec new_introspection(Clarity.Vertex.t(), module(), Clarity.Graph.t(), Queue.lane()) ::
          t()
  def new_introspection(vertex, introspector, graph, lane \\ :model) do
    %__MODULE__{
      id: make_ref(),
      vertex: vertex,
      introspector: introspector,
      graph: graph,
      lane: lane
    }
  end

  @doc """
  Returns a human-readable description of the task.
  """
  @spec describe(t()) :: String.t()
  def describe(%__MODULE__{vertex: vertex, introspector: introspector}) do
    vertex_name = Clarity.Vertex.name(vertex)
    introspector_name = introspector |> Module.split() |> List.last()
    "Introspect #{vertex_name} with #{introspector_name}"
  end
end
