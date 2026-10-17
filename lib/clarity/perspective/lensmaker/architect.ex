defmodule Clarity.Perspective.Lensmaker.Architect do
  @moduledoc """
  Architect lensmaker that provides a structural view of the application.

  The Architect lens focuses on the architectural and structural elements
  of the codebase, filtering out implementation details to show the high-level
  organization and relationships between major components: the project's own
  applications (and its path and umbrella dependencies), not the Hex packages
  it depends on, even one with an Ash domain of its own. It leaves out the
  graph, module documentation (the Documentation lens's), and `ash_diagram`'s
  policy diagram and simulation, which belong to the Security lens. It flags
  problems in the `:integrity` status class, such as a broken Ash signal.
  """

  @behaviour Clarity.Perspective.Lensmaker

  import Clarity.IconComponents
  import Phoenix.Component

  alias AshDiagram.ClarityContent
  alias Clarity.Config
  alias Clarity.Content
  alias Clarity.Dependency.Lock
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

        ~H"""
        <.icon_cube class="size-full" />
        """
      end,
      filter: &filter/1,
      show_vertex_types: &show_vertex_types/1,
      status_filter: &surface_status?/1,
      contents:
        {:except,
         [
           Content.Graph,
           Content.Moduledoc,
           ClarityContent.PolicyDiagram,
           ClarityContent.PolicySimulation
         ]}
    }
  end

  @spec surface_status?(Clarity.Status.t()) :: boolean()
  defp surface_status?(%Clarity.Status{class: class}), do: class == :integrity

  @spec filter(Graph.t()) :: Graph.query()
  defp filter(graph) do
    # The project's applications with architectural edges (beyond :module and
    # :dependency)
    project_apps = Config.project_applications()

    application_ids =
      graph
      |> Graph.vertices({:==, :vertex_type, Vertex.Application})
      |> Enum.filter(fn vertex ->
        own?(vertex.app, project_apps) and
          Enum.any?(
            [:domain, :router, :endpoint, :reactor, :signal_module],
            &(Graph.out_degree(graph, vertex, &1) > 0)
          )
      end)
      |> Enum.map(&Vertex.id/1)

    # Show: if Application type, only those with architectural edges; otherwise allow all
    {:or, {:in, :vertex_id, application_ids}, {:!=, :vertex_type, Vertex.Application}}
  end

  # Not a Hex package. In a release, without the Mix project to say which
  # applications are the project's, every one is.
  @spec own?(atom(), MapSet.t(atom()) | :all) :: boolean()
  defp own?(_app, :all), do: true
  defp own?(app, project_apps), do: app in project_apps or Lock.hex_package(app) == nil

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
      Vertex.Ash.Signal,
      Vertex.Ash.SignalModule,
      Vertex.Phoenix.Endpoint,
      Vertex.Phoenix.Router,
      Vertex.Reactor
    ]

    Enum.filter(available_types, &(&1 in architectural_types))
  end
end
