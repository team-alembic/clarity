defmodule Clarity.Perspective.Lensmaker.Security do
  @moduledoc """
  Security lensmaker that provides a security-focused view of the application.

  The Security lens focuses on security-related elements of the codebase,
  highlighting authentication, authorization, encryption, and other security
  concerns while filtering out unrelated implementation details.
  """

  @behaviour Clarity.Perspective.Lensmaker

  import Phoenix.Component

  alias Clarity.Graph
  alias Clarity.Perspective.Lens
  alias Clarity.Perspective.Lensmaker
  alias Clarity.Vertex
  alias Clarity.Vertex.Application
  alias Clarity.Vertex.Module

  @impl Lensmaker
  def make_lens do
    %Lens{
      id: "security",
      name: "Security",
      description: "Shows security-related components and authentication flows",
      icon: fn ->
        assigns = %{}
        ~H"🛡️"
      end,
      filter: &filter/1
    }
  end

  @spec filter(Graph.t()) :: (Vertex.t() -> boolean())
  defp filter(graph) do
    fn
      # Hide Applications from the navigation / graph. Without user
      # provided filters, this is too noisy to be useful.
      %Application{} = vertex ->
        graph
        |> Graph.out_edges(vertex)
        |> Enum.map(&Graph.edge(graph, &1))
        |> Enum.any?(fn
          {_id, ^vertex, _module, :module} -> false
          _other -> true
        end)

      # Hide Modules from the navigation / graph. Without user
      # provided filters, this is too noisy to be useful.
      %Module{} ->
        false

      # TODO: Add more specific filtering for security-related vertices
      # For now, we show all other vertices

      _vertex ->
        true
    end
  end
end
