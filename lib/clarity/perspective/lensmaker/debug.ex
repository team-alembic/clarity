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

  @spec filter(Graph.t()) :: (Vertex.t() -> boolean())
  defp filter(graph) do
    fn
      # Hide Applications from the navigation / graph. Without user
      # provided filters, this is too noisy to be useful.
      %Vertex.Application{} = vertex ->
        graph
        |> Graph.out_edges(vertex)
        |> Enum.map(&Graph.edge(graph, &1))
        |> Enum.any?(fn
          {_id, ^vertex, _module, :module} -> false
          _other -> true
        end)

      _vertex ->
        true
    end
  end
end
