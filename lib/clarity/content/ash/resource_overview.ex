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
         primary_key: Info.primary_key(resource),
         identities: Info.identities(resource),
         extensions: extensions(resource),
         attributes: Info.attributes(resource),
         relationships: Info.relationships(resource),
         attribute_visibility: resource |> Info.attributes() |> Overview.unusual_visibility(),
         keys_of:
           for(
             relationship <- Info.relationships(resource),
             relationship.type == :belongs_to,
             into: %{},
             do: {relationship.source_attribute, relationship(resource, relationship)}
           ),
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
      <div class="content w-full" id={@id}>
        <div class="ov-page">
          <div class="ov-head">
            <.hero vertex={@vertex} kind="Resource">
              <:badge>
                <.resource_badges links={@links} resource={@resource} />
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
              <:fact :if={@primary_key != []} label="Primary key">
                <.code_list names={Enum.map(@primary_key, &Atom.to_string/1)} />
              </:fact>
              <:fact :for={identity <- @identities} label="Unique">
                <span {Clarity.Tooltip.attrs("Identity #{identity.name}")}>
                  <.code_list names={Enum.map(identity.keys, &to_string/1)} />
                </span>
              </:fact>
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
                      <.flag :if={action.primary?} text="primary" />
                    </div>
                    <.description links={@links} text={description_of(action)} small sentence />
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
                <.attribute_flags
                  attribute={attribute}
                  unusual={@attribute_visibility}
                  links={@links}
                  key_of={@keys_of[attribute.name]}
                />
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
                  <.joined_by links={@links} relationship={relationship} resource={@resource} />
                </span>
              </:col>
              <:col
                :let={relationship}
                :if={
                  Enum.any?(
                    @relationships,
                    &(description_of(&1) || visibility_flagged?(&1, @relationship_visibility))
                  )
                }
                label="About"
              >
                <div class="ov-flags">
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
      </div>
      """
    end

    # What an aggregate reads: its relationship path, and the field there.
    @spec aggregate_target(Ash.Resource.Aggregate.t()) :: String.t()
    defp aggregate_target(aggregate) do
      Enum.map_join(aggregate.relationship_path ++ List.wrap(aggregate.field), ".", &to_string/1)
    end

    # The resource's extensions worth a mention: not Ash's own resource DSL,
    # nor those with pills of their own: its data layer, policies and state
    # machine.
    @spec extensions(module()) :: [String.t()]
    defp extensions(resource) do
      shown = [
        Ash.Resource.Dsl,
        Info.data_layer(resource),
        Ash.Policy.Authorizer,
        AshStateMachine
      ]

      resource
      |> Spark.extensions()
      |> Enum.reject(&(&1 in shown))
      |> Enum.map(&(&1 |> Module.split() |> List.last()))
    end

    # The attribute that joins a relationship's resources, on whichever side
    # it is: "by organization_id" on a belongs_to, the other resource's key
    # on a has_many or has_one.
    attr :links, :map, required: true
    attr :relationship, :any, required: true
    attr :resource, :atom, required: true

    @spec joined_by(map()) :: Phoenix.LiveView.Rendered.t()
    defp joined_by(assigns) do
      key =
        case assigns.relationship do
          %{type: :belongs_to, source_attribute: name} ->
            attribute_named(assigns.resource, name)

          %{type: type, destination: destination, destination_attribute: name}
          when type in [:has_many, :has_one] ->
            attribute_named(destination, name)

          _many_to_many ->
            nil
        end

      assigns = assign(assigns, :key, key)

      ~H"""
      <span :if={@key} class="ov-muted">by</span>
      <.vertex_link :if={@key} links={@links} vertex={@key} label={to_string(@key.attribute.name)} code />
      """
    end
  end
end
