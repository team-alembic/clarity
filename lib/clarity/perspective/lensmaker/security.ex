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
      %Vertex.Application{} = vertex ->
        total = Graph.out_degree(graph, vertex)
        module = Graph.out_degree(graph, vertex, :module)
        dependency = Graph.out_degree(graph, vertex, :dependency)

        total - module - dependency > 0

      %struct{}
      when struct in [
             Vertex.Ash.Action,
             Vertex.Ash.DataLayer,
             Vertex.Ash.Domain,
             Vertex.Ash.Policy,
             Vertex.Ash.Relationship,
             Vertex.Ash.Resource,
             Vertex.Phoenix.Router
           ] ->
        true

      _vertex ->
        false
    end
  end
end
