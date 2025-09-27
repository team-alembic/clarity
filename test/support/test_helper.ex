defmodule Clarity.Test.Helper do
  @moduledoc false

  import ExUnit.Callbacks

  alias Clarity.Vertex

  @doc """
  Creates a simple test Clarity struct with predictable vertices and edges.
  """
  @spec build_test_clarity() :: Clarity.t()
  def build_test_clarity do
    # Create a Clarity.Graph instance
    clarity_graph = Clarity.Graph.new()

    app_vertex = %Vertex.Application{
      app: :clarity,
      description: "Clarity App",
      version: Version.parse!("0.1.0")
    }

    domain_vertex = %Vertex.Ash.Domain{domain: Demo.Accounts.Domain}

    Clarity.Graph.add_vertex(clarity_graph, app_vertex, %Vertex.Root{})
    Clarity.Graph.add_vertex(clarity_graph, domain_vertex, app_vertex)

    Clarity.Graph.add_edge(clarity_graph, %Vertex.Root{}, app_vertex, :child)
    Clarity.Graph.add_edge(clarity_graph, app_vertex, domain_vertex, :child)

    # Create content vertices
    content_vertex = %Vertex.Content{
      id: "graph",
      name: "Graph Navigation",
      content: {:viz, fn %{theme: _theme} -> "digraph G { a -> b; }" end}
    }

    Clarity.Graph.add_vertex(clarity_graph, content_vertex, domain_vertex)
    Clarity.Graph.add_edge(clarity_graph, domain_vertex, content_vertex, :content)

    %Clarity{
      graph: clarity_graph,
      status: :done,
      queue_info: %{
        future_queue: 0,
        in_progress: 0,
        total_vertices: Clarity.Graph.vertex_count(clarity_graph)
      }
    }
  end

  @doc """
  Sets up a test Clarity agent using start_supervised and configures the process dictionary to use it.
  Returns the pid of the test agent.
  """
  @spec setup_test_clarity(clarity :: Clarity.t()) :: pid()
  def setup_test_clarity(clarity \\ build_test_clarity()) do
    start_supervised!({Clarity.Test.DummyServer, clarity})
  end
end
