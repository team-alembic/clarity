with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Content.Ash.AttributeOverview do
    @moduledoc """
    Content provider for an Ash attribute's overview.

    Leads with the attribute's type and resource, the values it may take and
    what's notable about it (a primary key, required, sensitive, private),
    then where its resource uses it: the actions that accept it, and the
    relationships and identities built on it. Its constraints, defaults and
    column follow as facts.
    """

    @behaviour Clarity.Content

    use Clarity.Web, :live_component

    import Clarity.Components.OverviewComponents
    import Clarity.Content.Ash.Overview

    alias Ash.Resource.Info
    alias Clarity.Vertex.Ash.Attribute
    alias Clarity.Vertex.Ash.Resource

    @impl Clarity.Content
    def name, do: "Attribute Overview"

    @impl Clarity.Content
    def description, do: "Overview of this Ash attribute"

    @impl Clarity.Content
    def sort_priority, do: -100

    @impl Clarity.Content
    def applies?(%Attribute{}, _lens), do: true
    def applies?(_vertex, _lens), do: false

    @impl Phoenix.LiveComponent
    def update(assigns, socket) do
      %Attribute{attribute: attribute, resource: resource} = assigns.vertex

      {:ok,
       socket
       |> assign(assigns)
       |> assign(
         links: links(assigns),
         attribute: attribute,
         resource: resource,
         one_of: one_of(attribute),
         constraints: Keyword.delete(List.wrap(attribute.constraints), :one_of),
         actions:
           Enum.filter(
             Info.actions(resource),
             &(attribute.name in List.wrap(Map.get(&1, :accept)))
           ),
         relationships:
           Enum.filter(
             Info.relationships(resource),
             &(&1.type == :belongs_to and &1.source_attribute == attribute.name)
           ),
         identities: Enum.filter(Info.identities(resource), &(attribute.name in &1.keys))
       )}
    end

    @impl Phoenix.LiveComponent
    def render(assigns) do
      ~H"""
      <div class="ov-page" id={@id}>
        <div class="ov-head">
          <.hero vertex={@vertex} kind="Attribute">
            <:badge :if={@attribute.primary_key?}>
              <.flag kind={:key}>primary key</.flag>
            </:badge>
            <:badge :if={not @attribute.allow_nil? and not @attribute.primary_key?}>
              <.flag kind={:warn}>required</.flag>
            </:badge>
            <:badge :if={@attribute.sensitive?}>
              <.flag kind={:danger}>sensitive</.flag>
            </:badge>
            <:badge>
              <.flag :if={@attribute.public?} kind={:good}>public</.flag>
              <.flag :if={not @attribute.public?} kind={:muted}>private</.flag>
            </:badge>
            <:badge :if={@attribute.generated?}>
              <.flag kind={:muted}>generated</.flag>
            </:badge>
            <:badge :if={not @attribute.writable?}>
              <.flag kind={:muted}>read-only</.flag>
            </:badge>
            <:headline>
              <span class="ov-phrase">
                <.ash_type links={@links} type={@attribute.type} />
                <span class="ov-muted">on</span>
                <.vertex_link links={@links} vertex={%Resource{resource: @resource}} />
              </span>
            </:headline>
            <div :if={@one_of} class="ov-phrase">
              <span class="ov-muted">One of</span>
              <.code_list names={@one_of} max={20} />
            </div>
            <.description links={@links} text={description_of(@attribute)} lead />
          </.hero>

          <.facts>
            <:fact :if={Map.get(@attribute, :default) != nil} label="Default">
              <code class="ov-code">{value(@attribute.default)}</code>
            </:fact>
            <:fact :if={Map.get(@attribute, :update_default) != nil} label="On update">
              <code class="ov-code">{value(@attribute.update_default)}</code>
            </:fact>
            <:fact :for={{key, value} <- @constraints} label={humanize(key)}>
              <code class="ov-code">{inspect(value)}</code>
            </:fact>
            <:fact :if={@attribute.source && @attribute.source != @attribute.name} label="Column">
              <code class="ov-code">{@attribute.source}</code>
            </:fact>
            <:fact :if={not @attribute.filterable? or not @attribute.sortable?} label="Queries">
              {[
                if(not @attribute.filterable?, do: "not filterable"),
                if(not @attribute.sortable?, do: "not sortable")
              ]
              |> Enum.reject(&is_nil/1)
              |> Enum.join(", ")}
            </:fact>
            <:fact :if={@attribute.always_select? or not @attribute.select_by_default?} label="Selected">
              {if @attribute.always_select?, do: "always", else: "only when asked for"}
            </:fact>
          </.facts>
        </div>

        <.section
          :if={@actions != [] or @relationships != [] or @identities != []}
          id="used-by"
          title="Used by"
          icon="resource"
          tone="structure"
        >
          <.facts>
            <:fact :if={@actions != []} label="Accepted by">
              <span class="ov-phrase">
                <.vertex_link
                  :for={action <- @actions}
                  links={@links}
                  vertex={action(@resource, action)}
                  label={Atom.to_string(action.name)}
                  code
                />
              </span>
            </:fact>
            <:fact :if={@relationships != []} label="Key of">
              <span class="ov-phrase">
                <.vertex_link
                  :for={relationship <- @relationships}
                  links={@links}
                  vertex={relationship(@resource, relationship)}
                  label={Atom.to_string(relationship.name)}
                  code
                />
              </span>
            </:fact>
            <:fact :for={identity <- @identities} label="Unique, as">
              <code class="ov-code">{identity.name}</code>
              <span :if={length(identity.keys) > 1} class="ov-muted">
                with {identity.keys |> List.delete(@attribute.name) |> Enum.join(", ")}
              </span>
            </:fact>
          </.facts>
        </.section>
      </div>
      """
    end

    # A default as written: its value, or the function that makes one.
    @spec value(term()) :: String.t()
    defp value({module, function, args}) when is_atom(module) and is_atom(function),
      do: "#{inspect(module)}.#{function}/#{length(args)}"

    defp value(value), do: inspect(value)

    @spec humanize(atom()) :: String.t()
    defp humanize(key),
      do: key |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
  end
end
