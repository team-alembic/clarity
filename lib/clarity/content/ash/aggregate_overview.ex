with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Content.Ash.AggregateOverview do
    @moduledoc """
    Content provider for an Ash aggregate's overview.

    Leads with what the aggregate computes ("sum of total_cents") and the
    type it returns, then the path it follows from its resource, through
    each relationship, to the field it reads, and what narrows or orders
    the records it reads.
    """

    @behaviour Clarity.Content

    use Clarity.Web, :live_component

    import Clarity.Components.OverviewComponents
    import Clarity.Content.Ash.Overview

    alias Ash.Resource.Info
    alias Clarity.Vertex.Ash.Aggregate
    alias Clarity.Vertex.Ash.Resource

    @impl Clarity.Content
    def name, do: "Aggregate Overview"

    @impl Clarity.Content
    def description, do: "Overview of this Ash aggregate"

    @impl Clarity.Content
    def sort_priority, do: -100

    @impl Clarity.Content
    def applies?(%Aggregate{}, _lens), do: true
    def applies?(_vertex, _lens), do: false

    @impl Phoenix.LiveComponent
    def update(assigns, socket) do
      %Aggregate{aggregate: aggregate, resource: resource} = assigns.vertex
      hops = hops(resource, aggregate.relationship_path)

      {:ok,
       socket
       |> assign(assigns)
       |> assign(
         links: links(assigns),
         aggregate: aggregate,
         resource: resource,
         hops: hops,
         field: field(hops, resource, aggregate.field),
         type: type(resource, aggregate)
       )}
    end

    @impl Phoenix.LiveComponent
    def render(assigns) do
      ~H"""
      <div class="ov-page" id={@id}>
        <div class="ov-head">
          <.hero vertex={@vertex} kind="Aggregate">
            <:badge :if={@aggregate.sensitive?}>
              <.flag kind={:danger}>sensitive</.flag>
            </:badge>
            <:badge>
              <.flag :if={@aggregate.public?} kind={:good}>public</.flag>
              <.flag :if={not @aggregate.public?} kind={:muted}>private</.flag>
            </:badge>
            <:badge :if={Map.get(@aggregate, :uniq?)}>
              <.flag>unique values</.flag>
            </:badge>
            <:badge :if={Map.get(@aggregate, :include_nil?)}>
              <.flag>includes nil</.flag>
            </:badge>
            <:headline>
              <span class="ov-phrase">
                <b>{@aggregate.kind}</b>
                <span class="ov-muted">of</span>
                <code class="ov-code">{target(@aggregate)}</code>
                <span :if={@type} class="ov-muted">returning</span>
                <.ash_type :if={@type} links={@links} type={@type} />
              </span>
            </:headline>
            <.description links={@links} text={description_of(@aggregate)} lead />
          </.hero>

          <div class="ov-joins">
            <div class="ov-join">
              <.vertex_link links={@links} vertex={%Resource{resource: @resource}} />
              <%= for {relationship, from} <- @hops do %>
                <span class="ov-join-arrow">→</span>
                <.vertex_link
                  links={@links}
                  vertex={relationship(from, relationship)}
                  label={Atom.to_string(relationship.name)}
                  code
                />
                <span class="ov-join-arrow">→</span>
                <.vertex_link links={@links} vertex={%Resource{resource: relationship.destination}} />
              <% end %>
              <span :if={@field} class="ov-muted">.</span>
              <.vertex_link
                :if={@field}
                links={@links}
                vertex={@field}
                label={to_string(@aggregate.field)}
                icon={false}
                code
              />
            </div>
          </div>

          <.facts>
            <:fact :if={Map.get(@aggregate, :filter)} label="Filter">
              <code class="ov-code">{inspect(@aggregate.filter)}</code>
            </:fact>
            <:fact :if={List.wrap(Map.get(@aggregate, :sort)) != []} label="Sort">
              <code class="ov-code">{inspect(@aggregate.sort)}</code>
            </:fact>
            <:fact :if={List.wrap(Map.get(@aggregate, :join_filters)) != []} label="Join filters">
              <code class="ov-code">{inspect(@aggregate.join_filters)}</code>
            </:fact>
            <:fact :if={Map.get(@aggregate, :default) != nil} label="Default">
              <code class="ov-code">{inspect(@aggregate.default)}</code>
            </:fact>
            <:fact :if={Map.get(@aggregate, :read_action)} label="Read with">
              <code class="ov-code">{@aggregate.read_action}</code>
            </:fact>
            <:fact :if={Map.get(@aggregate, :implementation)} label="Implementation">
              <code class="ov-code">{inspect(@aggregate.implementation)}</code>
            </:fact>
            <:fact :if={Map.get(@aggregate, :authorize?) == false} label="Authorize">no</:fact>
            <:fact :if={not @aggregate.filterable? or not @aggregate.sortable?} label="Queries">
              {[
                if(not @aggregate.filterable?, do: "not filterable"),
                if(not @aggregate.sortable?, do: "not sortable")
              ]
              |> Enum.reject(&is_nil/1)
              |> Enum.join(", ")}
            </:fact>
          </.facts>
        </div>
      </div>
      """
    end

    # Each relationship along the path, with the resource it leaves from.
    @spec hops(module(), [atom()]) :: [{Ash.Resource.Relationships.relationship(), module()}]
    defp hops(resource, path) do
      {hops, _resource} =
        Enum.flat_map_reduce(path, resource, fn name, from ->
          case Info.relationship(from, name) do
            nil -> {:halt, from}
            relationship -> {[{relationship, from}], relationship.destination}
          end
        end)

      hops
    end

    # The attribute the aggregate reads, at the end of its path.
    @spec field([{map(), module()}], module(), atom() | nil) :: struct() | nil
    defp field(_hops, _resource, nil), do: nil

    defp field(hops, resource, name) do
      destination =
        case List.last(hops) do
          nil -> resource
          {relationship, _from} -> relationship.destination
        end

      attribute_named(destination, name)
    end

    @spec target(Ash.Resource.Aggregate.t()) :: String.t()
    defp target(aggregate),
      do:
        Enum.map_join(
          aggregate.relationship_path ++ List.wrap(aggregate.field),
          ".",
          &to_string/1
        )

    @spec type(module(), Ash.Resource.Aggregate.t()) :: term()
    defp type(resource, aggregate) do
      case Info.aggregate_type(resource, aggregate) do
        {:ok, type} -> type
        _unknown -> nil
      end
    end
  end
end
