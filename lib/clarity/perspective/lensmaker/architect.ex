defmodule Clarity.Perspective.Lensmaker.Architect do
  @moduledoc """
  Architect lensmaker that provides a structural view of the application.

  The Architect lens focuses on the architectural and structural elements
  of the codebase, filtering out implementation details to show the high-level
  organization and relationships between major components.
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
      id: "architect",
      name: "Architect",
      description: "Shows architectural structure and major components",
      icon: fn ->
        assigns = %{}
        ~H"🏗️"
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

      # TODO: Add more specific filtering for architectural-related vertices
      # for now, show everything else

      _vertex ->
        true
    end
  end
end
