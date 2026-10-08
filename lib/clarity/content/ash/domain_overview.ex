with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Content.Ash.DomainOverview do
    @moduledoc """
    Content provider for an Ash domain's overview.

    Leads with the domain's description, its application and how much it
    holds, then a card for each resource: its name, data layer and what's
    notable, its description in brief, and its counts of actions, attributes
    and relationships. With short names (the `name_style` prop), the domain is
    named within its application and its resources within it.
    """

    @behaviour Clarity.Content

    use Clarity.Web, :live_component

    import Clarity.Components.OverviewComponents
    import Clarity.Content.Ash.Overview

    alias Ash.Domain.Info
    alias Clarity.Vertex
    alias Clarity.Vertex.Ash.Domain

    @impl Clarity.Content
    def name, do: "Domain Overview"

    @impl Clarity.Content
    def description, do: "Overview of this Ash domain"

    @impl Clarity.Content
    def sort_priority, do: -100

    @impl Clarity.Content
    def applies?(%Domain{}, _lens), do: true
    def applies?(_vertex, _lens), do: false

    @impl Phoenix.LiveComponent
    def update(assigns, socket) do
      %Domain{domain: domain} = assigns.vertex
      resources = Info.resources(domain)
      links = links(assigns)

      {:ok,
       socket
       |> assign(assigns)
       |> assign(
         links: links,
         domain: domain,
         description: module_description(domain, Info.description(domain)),
         app: app_vertex(links, Application.get_application(domain)),
         resources: resources,
         common_data_layer: common_data_layer(resources),
         action_count:
           resources |> Enum.map(&length(Ash.Resource.Info.actions(&1))) |> Enum.sum(),
         short?: Map.get(assigns, :name_style, :qualified) == :short
       )}
    end

    @impl Phoenix.LiveComponent
    def render(assigns) do
      ~H"""
      <div class="content w-full" id={@id}>
        <div class="ov-page">
          <div class="ov-head">
            <.hero vertex={@vertex} kind="Domain">
              <.description links={@links} text={@description} lead />
            </.hero>

            <.facts>
              <:fact label="Domain">
                <.vertex_link
                  links={@links}
                  vertex={@vertex}
                  label={if @short?, do: Vertex.Name.in_app(@domain), else: inspect(@domain)}
                />
              </:fact>
              <:fact :if={@app} label="Application">
                <.vertex_link links={@links} vertex={@app} />
              </:fact>
              <:fact label="Resources">{length(@resources)}</:fact>
              <:fact :if={@common_data_layer} label="Data layer">
                <.vertex_link
                  links={@links}
                  vertex={%Clarity.Vertex.Ash.DataLayer{data_layer: @common_data_layer}}
                  label={@common_data_layer |> Module.split() |> List.last()}
                />
              </:fact>
              <:fact label="Actions">{@action_count}</:fact>
            </.facts>
          </div>

          <.section
            id="resources"
            title="Resources"
            icon="resource"
            tone="structure"
            count={length(@resources)}
          >
            <p :if={@resources == []} class="ov-muted">This domain has no resources.</p>
            <div :if={@resources != []} class="ov-cards">
              <.resource_card
                :for={resource <- @resources}
                links={links_about(@links, %Vertex.Ash.Resource{resource: resource})}
                resource={resource}
                common_data_layer={@common_data_layer}
                label={if @short?, do: Vertex.Name.within(resource, @domain), else: inspect(resource)}
              />
            </div>
          </.section>
        </div>
      </div>
      """
    end

    @spec app_vertex(map(), atom() | nil) :: Vertex.Application.t() | nil
    defp app_vertex(_links, nil), do: nil

    defp app_vertex(links, app),
      do: in_graph(links, %Vertex.Application{app: app, description: nil, version: nil})
  end
end
