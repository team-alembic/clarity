defmodule Clarity.TestHelper do
  @moduledoc false

  import ExUnit.Callbacks

  alias Clarity.Vertex

  @doc """
  Creates a simple test Clarity struct with predictable vertices and edges.
  """
  @spec build_test_clarity() :: Clarity.t()
  def build_test_clarity do
    graph = :digraph.new()

    # Create vertices
    root_vertex = %Vertex.Root{}

    app_vertex = %Vertex.Application{
      app: :clarity,
      description: "Clarity App",
      version: Version.parse!("0.1.0")
    }

    domain_vertex = %Vertex.Ash.Domain{domain: Demo.Accounts.Domain}

    # Add vertices to graph
    :digraph.add_vertex(graph, root_vertex)
    :digraph.add_vertex(graph, app_vertex)
    :digraph.add_vertex(graph, domain_vertex)

    # Add edges
    :digraph.add_edge(graph, root_vertex, app_vertex, :child)
    :digraph.add_edge(graph, app_vertex, domain_vertex, :child)

    # Create content vertices
    content_vertex = %Vertex.Content{
      id: "graph",
      name: "Graph Navigation",
      content: {:viz, fn %{theme: _theme} -> "digraph G { a -> b; }" end}
    }

    # Add content to graph
    :digraph.add_vertex(graph, content_vertex)
    :digraph.add_edge(graph, root_vertex, content_vertex, :content)

    # Build vertices map
    vertices = %{
      "root" => root_vertex,
      "application:clarity" => app_vertex,
      "domain:Demo.Accounts.Domain" => domain_vertex
    }

    # Build tree structure matching Clarity.tree() format
    tree = %{
      node: root_vertex,
      children: %{
        :child => [
          %{
            node: app_vertex,
            children: %{
              :child => [
                %{
                  node: domain_vertex,
                  children: %{}
                }
              ]
            }
          }
        ]
      }
    }

    %Clarity{
      graph: graph,
      vertices: vertices,
      root: root_vertex,
      tree: tree
    }
  end

  @doc """
  Sets up a test Clarity agent using start_supervised and configures the process dictionary to use it.
  Returns the pid of the test agent.
  """
  @spec setup_test_clarity(clarity :: Clarity.t()) :: pid()
  def setup_test_clarity(clarity \\ build_test_clarity()) do
    pid = start_supervised!({Agent, fn -> clarity end})

    pid
  end
end
