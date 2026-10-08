with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Content.Ash.RelationshipOverview do
    @moduledoc """
    Content provider for an Ash relationship's overview.

    Leads with the relationship as a sentence ("Ticket belongs to one
    Project") and how the two resources' keys join, through the join
    resource for a many-to-many, then what narrows or orders it and what
    the relationship allows.
    """

    @behaviour Clarity.Content

    use Clarity.Web, :live_component

    import Clarity.Components.OverviewComponents
    import Clarity.Content.Ash.Overview

    alias Clarity.Vertex.Ash.Relationship
    alias Clarity.Vertex.Ash.Resource
    alias Phoenix.LiveView.Rendered

    @impl Clarity.Content
    def name, do: "Relationship Overview"

    @impl Clarity.Content
    def description, do: "Overview of this Ash relationship"

    @impl Clarity.Content
    def sort_priority, do: -100

    @impl Clarity.Content
    def applies?(%Relationship{}, _lens), do: true
    def applies?(_vertex, _lens), do: false

    @impl Phoenix.LiveComponent
    def update(assigns, socket) do
      %Relationship{relationship: relationship, resource: resource} = assigns.vertex

      {:ok,
       socket
       |> assign(assigns)
       |> assign(links: links(assigns), relationship: relationship, resource: resource)}
    end

    @impl Phoenix.LiveComponent
    def render(assigns) do
      ~H"""
      <div class="content w-full" id={@id}>
        <div class="ov-page">
          <div class="ov-head">
            <.hero vertex={@vertex} kind="Relationship">
              <:badge>
                <.flag>{@relationship.type}</.flag>
              </:badge>
              <:badge :if={@relationship.type == :belongs_to and not @relationship.allow_nil?}>
                <.flag text="required" />
              </:badge>
              <:badge :if={Map.get(@relationship, :primary_key?)}>
                <.flag text="primary key" />
              </:badge>
              <:badge>
                <.flag :if={@relationship.public?} text="public" />
                <.flag :if={not @relationship.public?} text="private" />
              </:badge>
              <:headline>
                <span class="ov-phrase">
                  <.vertex_link links={@links} vertex={%Resource{resource: @resource}} />
                  <span>{cardinality(@relationship)}</span>
                  <.vertex_link links={@links} vertex={%Resource{resource: @relationship.destination}} />
                  <span :if={@relationship.type == :many_to_many} class="ov-muted">through</span>
                  <.vertex_link
                    :if={@relationship.type == :many_to_many}
                    links={@links}
                    vertex={%Resource{resource: @relationship.through}}
                  />
                </span>
              </:headline>
              <.description links={@links} text={description_of(@relationship)} lead />
            </.hero>

            <div class="ov-joins">
              <%= if @relationship.type == :many_to_many do %>
                <.key_join
                  links={@links}
                  from={{@resource, @relationship.source_attribute}}
                  to={{@relationship.through, @relationship.source_attribute_on_join_resource}}
                />
                <.key_join
                  links={@links}
                  from={{@relationship.through, @relationship.destination_attribute_on_join_resource}}
                  to={{@relationship.destination, @relationship.destination_attribute}}
                />
              <% else %>
                <.key_join
                  links={@links}
                  from={{@resource, @relationship.source_attribute}}
                  to={{@relationship.destination, @relationship.destination_attribute}}
                />
              <% end %>
            </div>

            <.facts>
              <:fact :if={Map.get(@relationship, :read_action)} label="Read with">
                <code class="ov-code">{@relationship.read_action}</code>
              </:fact>
              <:fact :if={Map.get(@relationship, :filter)} label="Filter">
                <code class="ov-code">{inspect(@relationship.filter)}</code>
              </:fact>
              <:fact :if={List.wrap(Map.get(@relationship, :sort)) != []} label="Sort">
                <code class="ov-code">{inspect(@relationship.sort)}</code>
              </:fact>
              <:fact :if={Map.get(@relationship, :limit)} label="Limit">{@relationship.limit}</:fact>
              <:fact :if={Map.get(@relationship, :manual)} label="Manual">
                <code class="ov-code">{inspect(implementation(@relationship.manual))}</code>
              </:fact>
              <:fact :if={@relationship.type == :belongs_to} label="Key type">
                <.ash_type links={@links} type={@relationship.attribute_type} />
              </:fact>
              <:fact :if={Map.get(@relationship, :writable?, true) == false} label="Writable">no</:fact>
              <:fact
                :if={
                  Map.get(@relationship, :filterable?, true) == false or
                    Map.get(@relationship, :sortable?, true) == false
                }
                label="Queries"
              >
                {[
                  if(Map.get(@relationship, :filterable?, true) == false, do: "not filterable"),
                  if(Map.get(@relationship, :sortable?, true) == false, do: "not sortable")
                ]
                |> Enum.reject(&is_nil/1)
                |> Enum.join(", ")}
              </:fact>
            </.facts>
          </div>
        </div>
      </div>
      """
    end

    # One resource's key matching another's: Ticket.project_id → Project.id.
    attr :links, :map, required: true
    attr :from, :any, required: true, doc: "The resource and attribute the key is on"
    attr :to, :any, required: true, doc: "The resource and attribute it matches"

    @spec key_join(map()) :: Rendered.t()
    defp key_join(assigns) do
      ~H"""
      <div class="ov-join">
        <.key links={@links} key={@from} />
        <span class="ov-join-arrow" aria-label="matches">→</span>
        <.key links={@links} key={@to} />
      </div>
      """
    end

    attr :links, :map, required: true
    attr :key, :any, required: true

    @spec key(map()) :: Rendered.t()
    defp key(%{key: {resource, name}} = assigns) do
      assigns =
        assign(assigns,
          resource: resource,
          name: name,
          attribute: attribute_named(resource, name)
        )

      ~H"""
      <span class="ov-phrase">
        <.vertex_link links={@links} vertex={%Resource{resource: @resource}} />
        <span class="ov-muted">.</span>
        <.vertex_link
          :if={@attribute}
          links={@links}
          vertex={@attribute}
          label={to_string(@name)}
          icon={false}
          code
        />
        <code :if={!@attribute} class="ov-code">{@name}</code>
      </span>
      """
    end

    @spec implementation(term()) :: module()
    defp implementation({module, _opts}), do: module
    defp implementation(module), do: module
  end
end
