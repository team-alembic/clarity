defmodule Clarity.Perspective.Lensmaker.Debug do
  @moduledoc """
  Debug lensmaker that provides a comprehensive view of the graph structure.

  The Debug lens is designed for developers and debugging purposes, showing
  the most important vertices while filtering out noise. It provides a clean
  view of the graph structure suitable for navigation and exploration.
  """

  @behaviour Clarity.Perspective.Lensmaker

  import Phoenix.Component

  alias Clarity.Content
  alias Clarity.Graph
  alias Clarity.Perspective.Lens
  alias Clarity.Perspective.Lensmaker
  alias Clarity.Vertex

  @impl Lensmaker
  def make_lens do
    %Lens{
      id: "debug",
      name: "Debug",
      description: "Shows graph structure with noise filtering for debugging and development",
      icon: fn ->
        assigns = %{}
        ~H"🐛"
      end,
      filter: &filter/1,
      content_sorter: fn
        %Content{provider: Content.Graph}, _b -> true
        _a, %Content{provider: Content.Graph} -> false
        a, b -> Lens.sort_alphabetically(a, b)
      end
    }
  end

  @spec filter(Graph.t()) :: Graph.query()
  defp filter(graph) do
    # Find applications with "interesting" edges (beyond just :module)
    # This filters out noisy applications that only have module edges
    application_ids =
      graph
      |> Graph.vertices({:==, :vertex_type, Vertex.Application})
      |> Enum.filter(fn vertex ->
        Graph.out_degree(graph, vertex) - Graph.out_degree(graph, vertex, :module) > 0
      end)
      |> Enum.map(&Vertex.id/1)

    # Show applications with interesting edges OR any non-application vertex
    {:or, {:in, :vertex_id, application_ids}, {:!=, :vertex_type, Vertex.Application}}
  end
end
