defmodule Clarity.Server.Task do
  @moduledoc false

  @type t :: %__MODULE__{
          id: reference(),
          vertex: Clarity.Vertex.t(),
          introspector: module(),
          graph: Clarity.Graph.t(),
          created_at: integer()
        }

  defstruct [
    :id,
    :vertex,
    :introspector,
    :graph,
    :created_at
  ]

  @doc """
  Creates a new introspection task for a vertex.
  """
  @spec new_introspection(Clarity.Vertex.t(), module(), Clarity.Graph.t()) :: t()
  def new_introspection(vertex, introspector, graph) do
    %__MODULE__{
      id: make_ref(),
      vertex: vertex,
      introspector: introspector,
      graph: graph,
      created_at: System.monotonic_time(:millisecond)
    }
  end

  @doc """
  Returns a human-readable description of the task.
  """
  @spec describe(t()) :: String.t()
  def describe(%__MODULE__{vertex: vertex, introspector: introspector}) do
    vertex_name = Clarity.Vertex.render_name(vertex)
    introspector_name = introspector |> Module.split() |> List.last()
    "Introspect #{vertex_name} with #{introspector_name}"
  end
end
