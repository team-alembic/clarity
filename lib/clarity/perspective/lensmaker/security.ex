defmodule Clarity.Perspective.Lensmaker.Security do
  @moduledoc """
  Security lensmaker that provides a security-focused view of the application.

  The Security lens focuses on security-related elements of the codebase,
  highlighting authentication, authorization, encryption, and other security
  concerns while filtering out unrelated implementation details.
  """

  @behaviour Clarity.Perspective.Lensmaker

  import Phoenix.Component

  alias Clarity.Dependency
  alias Clarity.Dependency.Registry
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
    relevant =
      graph
      |> Graph.vertices({:==, :vertex_type, Vertex.Application})
      |> Enum.filter(&relevant_application?(graph, &1))

    application_ids =
      graph
      |> with_dependency_ancestors(relevant)
      |> MapSet.to_list()

    # Show: only the relevant applications (plus the dependency path that reaches
    # them); allow all non-application vertices through.
    {:or, {:in, :vertex_id, application_ids}, {:!=, :vertex_type, Vertex.Application}}
  end

  # A supply-chain-flagged dependency is often transitive, reachable in the tree
  # only through framework applications that aren't themselves security-relevant
  # (e.g. websock_adapter under phoenix). Keep those ancestor applications too,
  # so the flagged app stays reachable from the root and its dependency path —
  # how it's pulled in — is visible.
  @spec with_dependency_ancestors(Graph.t(), [Vertex.Application.t()]) :: MapSet.t(String.t())
  defp with_dependency_ancestors(graph, relevant) do
    collect_ancestors(graph, relevant, MapSet.new(relevant, &Vertex.id/1))
  end

  @spec collect_ancestors(Graph.t(), [Vertex.Application.t()], MapSet.t(String.t())) ::
          MapSet.t(String.t())
  defp collect_ancestors(_graph, [], visited), do: visited

  defp collect_ancestors(graph, [vertex | rest], visited) do
    parents =
      graph
      |> Graph.in_neighbors(vertex)
      |> Enum.filter(&match?(%Vertex.Application{}, &1))
      |> Enum.reject(&MapSet.member?(visited, Vertex.id(&1)))

    visited = Enum.reduce(parents, visited, &MapSet.put(&2, Vertex.id(&1)))
    collect_ancestors(graph, rest ++ parents, visited)
  end

  # An application is relevant to the security lens when it participates in the
  # architecture (Ash domains / Phoenix endpoints) or carries a supply-chain
  # concern: a security advisory, or an outdated/retired installed version.
  @spec relevant_application?(Graph.t(), Vertex.Application.t()) :: boolean()
  defp relevant_application?(graph, vertex) do
    has_security_edge?(graph, vertex) or supply_chain_flagged?(vertex)
  end

  @spec has_security_edge?(Graph.t(), Vertex.Application.t()) :: boolean()
  defp has_security_edge?(graph, vertex) do
    Enum.any?(
      [:domain, :router, :endpoint, :advisory],
      &(Graph.out_degree(graph, vertex, &1) > 0)
    )
  end

  @spec supply_chain_flagged?(Vertex.Application.t()) :: boolean()
  defp supply_chain_flagged?(%{app: app, version: version}) do
    case Registry.summary(app) do
      %{latest: latest, retired: retired} ->
        installed = to_string(version)
        installed in retired or Dependency.outdated?(installed, latest)

      nil ->
        false
    end
  end

  @spec show_vertex_types([module()]) :: [module()]
  defp show_vertex_types(available_types) do
    security_types = [
      Vertex.Advisory,
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
