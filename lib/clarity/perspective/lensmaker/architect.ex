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
      filter: &filter/1,
      show_vertex_types: &show_vertex_types/1
    }
  end

  @spec filter(Graph.t()) :: Graph.query()
  defp filter(graph) do
    # Find applications with architectural edges (beyond :module and :dependency)
    application_ids =
      graph
      |> Graph.vertices({:==, :vertex_type, Vertex.Application})
      |> Enum.filter(fn vertex ->
        Enum.any?([:domain, :router, :endpoint], &(Graph.out_degree(graph, vertex, &1) > 0))
      end)
      |> Enum.map(&Vertex.id/1)

    # Show: if Application type, only those with architectural edges; otherwise allow all
    {:or, {:in, :vertex_id, application_ids}, {:!=, :vertex_type, Vertex.Application}}
  end

  @spec show_vertex_types([module()]) :: [module()]
  defp show_vertex_types(available_types) do
    architectural_types = [
      Vertex.Application,
      Vertex.Ash.Aggregate,
      Vertex.Ash.Action,
      Vertex.Ash.Attribute,
      Vertex.Ash.Calculation,
      Vertex.Ash.Domain,
      Vertex.Ash.Policy,
      Vertex.Ash.Relationship,
      Vertex.Ash.Resource,
      Vertex.Phoenix.Endpoint,
      Vertex.Phoenix.Router
    ]

    Enum.filter(available_types, &(&1 in architectural_types))
  end
end
