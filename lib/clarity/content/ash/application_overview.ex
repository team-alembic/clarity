with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Content.Ash.ApplicationOverview do
    @moduledoc """
    Content provider for an application's Ash overview.

    Leads with the application's description, version and how much it holds,
    then a section for each Ash domain: its description, and a card for each
    of its resources. Text in a domain's section links names as text about
    that domain does, and a card's as text about its resource. With short
    names (the `name_style` prop), domains are named within the application
    and resources within their domains.
    """

    @behaviour Clarity.Content

    use Clarity.Web, :live_component

    import Clarity.Components.OverviewComponents
    import Clarity.Content.Ash.Overview

    alias Clarity.Vertex
    alias Clarity.Vertex.Application
    alias Clarity.Vertex.Ash.Domain

    @impl Clarity.Content
    def name, do: "Application Overview"

    @impl Clarity.Content
    def description, do: "Ash domains and resources defined in this application"

    @impl Clarity.Content
    def sort_priority, do: -100

    @impl Clarity.Content
    def applies?(%Application{app: app}, _lens) do
      Ash.Info.domains(app) != []
    end

    def applies?(_vertex, _lens), do: false

    @impl Phoenix.LiveComponent
    def update(assigns, socket) do
      %Application{app: app} = assigns.vertex
      domains = app |> Ash.Info.domains_and_resources() |> Enum.sort_by(&inspect(elem(&1, 0)))

      {:ok,
       socket
       |> assign(assigns)
       |> assign(
         links: links(assigns),
         domains: domains,
         resource_count: domains |> Enum.map(&length(elem(&1, 1))) |> Enum.sum(),
         common_data_layer: domains |> Enum.flat_map(&elem(&1, 1)) |> common_data_layer(),
         short?: Map.get(assigns, :name_style, :qualified) == :short
       )}
    end

    @impl Phoenix.LiveComponent
    def render(assigns) do
      ~H"""
      <div class="content w-full" id={@id}>
        <div class="ov-page">
          <div class="ov-head">
            <.hero vertex={@vertex} kind="Application">
              <.description
                :if={@vertex.description != Atom.to_string(@vertex.app)}
                links={@links}
                text={@vertex.description}
                lead
              />
            </.hero>

            <.facts>
              <:fact :if={@vertex.version} label="Version">{to_string(@vertex.version)}</:fact>
              <:fact label="Domains">{length(@domains)}</:fact>
              <:fact label="Resources">{@resource_count}</:fact>
              <:fact :if={@common_data_layer} label="Data layer">
                <.vertex_link
                  links={@links}
                  vertex={%Vertex.Ash.DataLayer{data_layer: @common_data_layer}}
                  label={@common_data_layer |> Module.split() |> List.last()}
                />
              </:fact>
            </.facts>

            <.stats>
              <:stat
                :for={{domain, resources} <- @domains}
                label={domain_label(domain, @short?)}
                count={length(resources)}
                href={"##{section_id(domain)}"}
                icon="domain"
                tone="structure"
              />
            </.stats>
          </div>

          <.domain_section
            :for={{domain, resources} <- @domains}
            links={links_about(@links, %Domain{domain: domain})}
            domain={domain}
            resources={resources}
            common_data_layer={@common_data_layer}
            short?={@short?}
          />
        </div>
      </div>
      """
    end

    attr :links, :map, required: true
    attr :domain, :atom, required: true
    attr :resources, :list, required: true
    attr :common_data_layer, :atom, required: true
    attr :short?, :boolean, required: true

    @spec domain_section(map()) :: Phoenix.LiveView.Rendered.t()
    defp domain_section(assigns) do
      assigns =
        assign(assigns,
          vertex: %Domain{domain: assigns.domain},
          description:
            module_description(assigns.domain, Ash.Domain.Info.description(assigns.domain))
        )

      ~H"""
      <section id={section_id(@domain)} class="ov-section ov-domain">
        <div class="ov-domain-head">
          <.vertex_link
            links={@links}
            vertex={@vertex}
            label={domain_label(@domain, @short?)}
            class="ov-domain-name"
          />
          <span class="ov-count">{length(@resources)}</span>
        </div>
        <.description links={@links} text={@description} class="mb-3" />
        <p :if={@resources == []} class="ov-muted">No resources defined.</p>
        <div :if={@resources != []} class="ov-cards">
          <.resource_card
            :for={resource <- @resources}
            links={links_about(@links, %Vertex.Ash.Resource{resource: resource})}
            resource={resource}
            common_data_layer={@common_data_layer}
            label={if @short?, do: Vertex.Name.within(resource, @domain), else: inspect(resource)}
          />
        </div>
      </section>
      """
    end

    @spec domain_label(module(), boolean()) :: String.t()
    defp domain_label(domain, true), do: Vertex.Name.in_app(domain)
    defp domain_label(domain, false), do: inspect(domain)

    @spec section_id(module()) :: String.t()
    defp section_id(domain), do: "domain-" <> (domain |> inspect() |> String.replace(".", "-"))
  end
end
