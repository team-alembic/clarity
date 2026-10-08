with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Content.Ash.ResourceOverview do
    @moduledoc """
    Content provider for an Ash resource's overview.

    Leads with what the resource is: its description, domain, data layer,
    primary key and identities, and counts that jump to its attributes,
    relationships, actions, aggregates and calculations. Each row calls out
    what's notable about its field (a primary key, a required or sensitive
    attribute) instead of columns of true and false.
    """

    @behaviour Clarity.Content

    use Clarity.Web, :live_component

    import Clarity.Components.OverviewComponents
    import Clarity.Content.Ash.Overview

    alias Ash.Resource.Info
    alias Clarity.Content.Ash.Overview
    alias Clarity.Vertex.Ash.DataLayer
    alias Clarity.Vertex.Ash.Domain
    alias Clarity.Vertex.Ash.Resource

    @action_types [:create, :read, :update, :destroy, :action]

    @impl Clarity.Content
    def name, do: "Resource Overview"

    @impl Clarity.Content
    def description, do: "Overview of this Ash resource"

    @impl Clarity.Content
    def sort_priority, do: -100

    @impl Clarity.Content
    def applies?(%Resource{}, _lens), do: true
    def applies?(_vertex, _lens), do: false

    @impl Phoenix.LiveComponent
    def update(assigns, socket) do
      %Resource{resource: resource} = assigns.vertex
      actions = Info.actions(resource)

      {:ok,
       socket
       |> assign(assigns)
       |> assign(
         links: links(assigns),
         resource: resource,
         description: Overview.module_description(resource, Info.description(resource)),
         domain: Info.domain(resource),
         data_layer: Info.data_layer(resource),
         primary_key: Info.primary_key(resource),
         identities: Info.identities(resource),
         extensions: extensions(resource),
         embedded?: Info.embedded?(resource),
         multitenancy: Info.multitenancy_strategy(resource),
         attributes: Info.attributes(resource),
         relationships: Info.relationships(resource),
         attribute_visibility: resource |> Info.attributes() |> Overview.unusual_visibility(),
         relationship_visibility:
           resource |> Info.relationships() |> Overview.unusual_visibility(),
         action_groups:
           for(
             type <- @action_types,
             group = Enum.filter(actions, &(&1.type == type)),
             group != [],
             do: {type, group}
           ),
         action_count: length(actions),
         aggregates: Info.aggregates(resource),
         calculations: Info.calculations(resource)
       )}
    end

    @impl Phoenix.LiveComponent
    def render(assigns) do
      ~H"""
      <div class="ov-page" id={@id}>
        <div class="ov-head">
          <.hero vertex={@vertex} kind="Resource">
            <:badge :if={@embedded?}>
              <.flag>embedded</.flag>
            </:badge>
            <:badge :if={@multitenancy}>
              <.flag kind={:warn}>multitenant</.flag>
            </:badge>
            <:badge :for={extension <- @extensions}>
              <.flag>{extension}</.flag>
            </:badge>
            <.description links={@links} text={@description} lead />
          </.hero>

          <.facts>
            <:fact :if={@domain} label="Domain">
              <.vertex_link links={@links} vertex={%Domain{domain: @domain}} />
            </:fact>
            <:fact :if={@data_layer} label="Data layer">
              <.vertex_link
                links={@links}
                vertex={%DataLayer{data_layer: @data_layer}}
                label={@data_layer |> Module.split() |> List.last()}
              />
            </:fact>
            <:fact :if={@primary_key != []} label="Primary key">
              <.code_list names={Enum.map(@primary_key, &Atom.to_string/1)} />
            </:fact>
            <:fact :for={identity <- @identities} label="Unique">
              <span {Clarity.Tooltip.attrs("Identity #{identity.name}")}>
                <.code_list names={Enum.map(identity.keys, &to_string/1)} />
              </span>
            </:fact>
            <:fact :if={@multitenancy} label="Multitenancy">{@multitenancy}</:fact>
          </.facts>

          <.stats>
            <:stat
              :if={@action_count > 0}
              label="actions"
              count={@action_count}
              href="#actions"
              icon="action"
              tone="behaviour"
            />
            <:stat
              :if={@attributes != []}
              label="attributes"
              count={length(@attributes)}
              href="#attributes"
              icon="attribute"
              tone="data"
            />
            <:stat
              :if={@relationships != []}
              label="relationships"
              count={length(@relationships)}
              href="#relationships"
              icon="relationship"
              tone="data"
            />
            <:stat
              :if={@aggregates != []}
              label="aggregates"
              count={length(@aggregates)}
              href="#aggregates"
              icon="aggregate"
              tone="behaviour"
            />
            <:stat
              :if={@calculations != []}
              label="calculations"
              count={length(@calculations)}
              href="#calculations"
              icon="calculation"
              tone="behaviour"
            />
          </.stats>
        </div>

        <.section
          :if={@action_count > 0}
          id="actions"
          title="Actions"
          icon="action"
          tone="behaviour"
          count={@action_count}
        >
          <div class="ov-cards">
            <div :for={{type, actions} <- @action_groups} class="ov-card">
              <h3 class="ov-card-title">{type} <span class="ov-count">{length(actions)}</span></h3>
              <ul class="ov-list">
                <li :for={action <- actions}>
                  <div class="flex items-center gap-1.5">
                    <.vertex_link
                      links={@links}
                      vertex={action(@resource, action)}
                      label={Atom.to_string(action.name)}
                      code
                    />
                    <.flag :if={action.primary?} kind={:key}>primary</.flag>
                  </div>
                  <.description links={@links} text={description_of(action)} class="line-clamp-2" small />
                </li>
              </ul>
            </div>
          </div>
        </.section>

        <.section
          :if={@attributes != []}
          id="attributes"
          title="Attributes"
          icon="attribute"
          tone="data"
          count={length(@attributes)}
        >
          <.overview_table id="resource-attributes" rows={@attributes}>
            <:col :let={attribute} label="Name" class="w-0 whitespace-nowrap">
              <.vertex_link
                links={@links}
                vertex={attribute(@resource, attribute)}
                label={Atom.to_string(attribute.name)}
                code
              />
            </:col>
            <:col :let={attribute} label="Type" class="w-0 whitespace-nowrap">
              <.ash_type links={@links} type={attribute.type} />
            </:col>
            <:col :let={attribute} label="About">
              <.attribute_flags attribute={attribute} unusual={@attribute_visibility} />
              <.description links={@links} text={description_of(attribute)} class="mt-0.5" />
            </:col>
          </.overview_table>
        </.section>

        <.section
          :if={@relationships != []}
          id="relationships"
          title="Relationships"
          icon="relationship"
          tone="data"
          count={length(@relationships)}
        >
          <.overview_table id="resource-relationships" rows={@relationships}>
            <:col :let={relationship} label="Name" class="w-0 whitespace-nowrap">
              <.vertex_link
                links={@links}
                vertex={relationship(@resource, relationship)}
                label={Atom.to_string(relationship.name)}
                code
              />
            </:col>
            <:col :let={relationship} label="Relates to" class="whitespace-nowrap">
              <span class="ov-phrase">
                <span class="ov-muted">{cardinality(relationship)}</span>
                <.vertex_link
                  links={@links}
                  vertex={%Resource{resource: relationship.destination}}
                />
                <span :if={relationship.type == :many_to_many} class="ov-muted">through</span>
                <.vertex_link
                  :if={relationship.type == :many_to_many}
                  links={@links}
                  vertex={%Resource{resource: relationship.through}}
                />
              </span>
            </:col>
            <:col :let={relationship} label="About">
              <div class="ov-flags">
                <.flag :if={relationship.type == :belongs_to}>
                  <code>{relationship.source_attribute}</code>
                </.flag>
                <.visibility_flag field={relationship} unusual={@relationship_visibility} />
              </div>
              <.description links={@links} text={description_of(relationship)} class="mt-0.5" />
            </:col>
          </.overview_table>
        </.section>

        <.section
          :if={@aggregates != []}
          id="aggregates"
          title="Aggregates"
          icon="aggregate"
          tone="behaviour"
          count={length(@aggregates)}
        >
          <.overview_table id="resource-aggregates" rows={@aggregates}>
            <:col :let={aggregate} label="Name" class="w-0 whitespace-nowrap">
              <.vertex_link
                links={@links}
                vertex={aggregate(@resource, aggregate)}
                label={Atom.to_string(aggregate.name)}
                code
              />
            </:col>
            <:col :let={aggregate} label="Computes" class="whitespace-nowrap">
              <span class="ov-phrase">
                <b class="font-medium">{aggregate.kind}</b>
                <span class="ov-muted">of</span>
                <code class="ov-code">{aggregate_target(aggregate)}</code>
              </span>
            </:col>
            <:col :let={aggregate} :if={Enum.any?(@aggregates, &description_of/1)} label="About">
              <.description links={@links} text={description_of(aggregate)} />
            </:col>
          </.overview_table>
        </.section>

        <.section
          :if={@calculations != []}
          id="calculations"
          title="Calculations"
          icon="calculation"
          tone="behaviour"
          count={length(@calculations)}
        >
          <.overview_table id="resource-calculations" rows={@calculations}>
            <:col :let={calculation} label="Name" class="w-0 whitespace-nowrap">
              <.vertex_link
                links={@links}
                vertex={calculation(@resource, calculation)}
                label={Atom.to_string(calculation.name)}
                code
              />
            </:col>
            <:col :let={calculation} label="Type" class="w-0 whitespace-nowrap">
              <.ash_type links={@links} type={calculation.type} />
            </:col>
            <:col :let={calculation} label="Computes">
              <.computation calculation={calculation} />
              <div :if={calculation.arguments != []} class="ov-flags mt-1">
                <.flag>
                  {length(calculation.arguments)} {if length(calculation.arguments) == 1,
                    do: "argument",
                    else: "arguments"}
                </.flag>
              </div>
              <.description links={@links} text={description_of(calculation)} class="mt-0.5" />
            </:col>
          </.overview_table>
        </.section>
      </div>
      """
    end

    # What an aggregate reads: its relationship path, and the field there.
    @spec aggregate_target(Ash.Resource.Aggregate.t()) :: String.t()
    defp aggregate_target(aggregate) do
      Enum.map_join(aggregate.relationship_path ++ List.wrap(aggregate.field), ".", &to_string/1)
    end

    # The resource's extensions worth a mention: not Ash's own resource DSL,
    # nor its data layer, which has a fact of its own.
    @spec extensions(module()) :: [String.t()]
    defp extensions(resource) do
      data_layer = Info.data_layer(resource)

      resource
      |> Spark.extensions()
      |> Enum.reject(&(&1 in [Ash.Resource.Dsl, data_layer]))
      |> Enum.map(&extension_name/1)
    end

    @spec extension_name(module()) :: String.t()
    defp extension_name(Ash.Policy.Authorizer), do: "policies"
    defp extension_name(AshStateMachine), do: "state machine"
    defp extension_name(extension), do: extension |> Module.split() |> List.last()
  end
end
