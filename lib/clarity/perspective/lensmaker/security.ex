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
      filter: &filter/1,
      show_vertex_types: &show_vertex_types/1
    }
  end

  @spec filter(Graph.t()) :: Graph.query()
  defp filter(graph) do
    # Find applications with security-related edges (beyond :module and :dependency)
    application_ids =
      graph
      |> Graph.vertices({:==, :vertex_type, Vertex.Application})
      |> Enum.filter(fn vertex ->
        Enum.any?([:domain, :router, :endpoint], &(Graph.out_degree(graph, vertex, &1) > 0))
      end)
      |> Enum.map(&Vertex.id/1)

    # Show: if Application type, only those with security edges; otherwise allow all
    {:or, {:in, :vertex_id, application_ids}, {:!=, :vertex_type, Vertex.Application}}
  end

  @spec show_vertex_types([module()]) :: [module()]
  defp show_vertex_types(available_types) do
    security_types = [
      Vertex.Application,
      Vertex.Ash.Action,
      Vertex.Ash.DataLayer,
      Vertex.Ash.Domain,
      Vertex.Ash.Policy,
      Vertex.Ash.Relationship,
      Vertex.Ash.Resource,
      Vertex.Phoenix.Router
    ]

    Enum.filter(available_types, &(&1 in security_types))
  end
end
