defmodule Clarity.Test.Helper do
  @moduledoc false

  import ExUnit.Callbacks

  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Domain
  alias Clarity.Vertex.Ash.Resource

  @doc """
  Creates a simple test Clarity struct with predictable vertices and edges.

  ## Options

    * `:internals` - also add an `ash` dependency owning one of Ash's shadow
      domains, a framework internal (see `Clarity.Perspective.Internals`)
    * `:modules` - also give the `clarity` application a module, so its
      children fall into two groups (a lone group gets no row in the tree)
    * `:resources` - also give the Accounts domain its `Demo.Accounts.User`
      resource
  """
  @spec build_test_clarity(keyword()) :: Clarity.t()
  def build_test_clarity(opts \\ []) do
    # Create a Clarity.Graph instance
    clarity_graph = Clarity.Graph.new()

    app_vertex = %Vertex.Application{
      app: :clarity,
      description: "Clarity App",
      version: Version.parse!("0.1.0")
    }

    domain_vertex = %Domain{domain: Demo.Accounts}

    Clarity.Graph.add_vertex(clarity_graph, app_vertex, %Vertex.Root{})
    Clarity.Graph.add_vertex(clarity_graph, domain_vertex, app_vertex)

    Clarity.Graph.add_edge(clarity_graph, %Vertex.Root{}, app_vertex, :child)
    Clarity.Graph.add_edge(clarity_graph, app_vertex, domain_vertex, :child)

    if opts[:modules] do
      module_vertex = %Vertex.Module{module: Demo.Accounts}
      Clarity.Graph.add_vertex(clarity_graph, module_vertex, app_vertex)
      Clarity.Graph.add_edge(clarity_graph, app_vertex, module_vertex, :module)
    end

    if opts[:resources] do
      resource_vertex = %Resource{resource: Demo.Accounts.User}
      Clarity.Graph.add_vertex(clarity_graph, resource_vertex, domain_vertex)
      Clarity.Graph.add_edge(clarity_graph, domain_vertex, resource_vertex, :resource)
    end

    if opts[:internals] do
      ash_vertex = %Vertex.Application{
        app: :ash,
        description: "A declarative, extensible framework for building Elixir applications.",
        version: Version.parse!("3.0.0")
      }

      shadow_vertex = %Domain{domain: Ash.EmbeddableType.ShadowDomain}

      Clarity.Graph.add_vertex(clarity_graph, ash_vertex, app_vertex)
      Clarity.Graph.add_vertex(clarity_graph, shadow_vertex, ash_vertex)

      Clarity.Graph.add_edge(clarity_graph, app_vertex, ash_vertex, :dependency)
      Clarity.Graph.add_edge(clarity_graph, ash_vertex, shadow_vertex, :domain)
    end

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
    pid = start_supervised!({Clarity.Test.DummyServer, clarity})

    # The graph's ETS tables die with their owner. Left with the test process,
    # they vanish the moment the test exits, while a LiveView under test can
    # still be rendering a late async result against them. The supervised
    # server outlives that LiveView, so it should own them.
    {:ok, graph} = Clarity.Graph.handover(clarity.graph, pid)
    :ok = GenServer.call(pid, {:put_graph, graph})

    pid
  end
end
