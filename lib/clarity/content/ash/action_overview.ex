with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Content.Ash.ActionOverview do
    @moduledoc """
    Content provider for an Ash action's overview.

    Leads with what the action does and to which resource ("Creates a
    Ticket"), whether it's primary, and its settings that matter, then its
    inputs (the attributes it accepts and its arguments, with which are
    required) and the steps it takes: its changes, validations or
    preparations, written as calls.
    """

    @behaviour Clarity.Content

    use Clarity.Web, :live_component

    import Clarity.Components.OverviewComponents
    import Clarity.Content.Ash.Overview

    alias Ash.Resource.Actions
    alias Ash.Resource.Info
    alias Clarity.Vertex.Ash.Action
    alias Clarity.Vertex.Ash.Resource
    alias Clarity.Vertex.Reactor

    @impl Clarity.Content
    def name, do: "Action Overview"

    @impl Clarity.Content
    def description, do: "Overview of this Ash action"

    @impl Clarity.Content
    def sort_priority, do: -100

    @impl Clarity.Content
    def applies?(%Action{}, _lens), do: true
    def applies?(_vertex, _lens), do: false

    @impl Phoenix.LiveComponent
    def update(assigns, socket) do
      %Action{action: action, resource: resource} = assigns.vertex

      {:ok,
       socket
       |> assign(assigns)
       |> assign(
         links: links(assigns),
         action: action,
         resource: resource,
         inputs: inputs(action, resource),
         steps: steps(action),
         runs: runs(action)
       )}
    end

    @impl Phoenix.LiveComponent
    def render(assigns) do
      ~H"""
      <div class="content w-full" id={@id}>
        <div class="ov-page">
          <div class="ov-head">
            <.hero vertex={@vertex} kind={kind(@action)} kind_hint={kind_hint(@action)}>
              <:badge :if={@action.primary?}>
                <.flag text="primary" />
              </:badge>
              <:badge :if={Map.get(@action, :manual)}>
                <.flag text="manual" />
              </:badge>
              <:badge :if={Map.get(@action, :upsert?)}>
                <.flag text="upsert" />
              </:badge>
              <:badge :if={Map.get(@action, :soft?)}>
                <.flag text="soft" />
              </:badge>
              <:badge :if={Map.get(@action, :get?)}>
                <.flag text="gets one" />
              </:badge>
              <:headline>
                <span class="ov-phrase">
                  {verb(@action)}
                  <.vertex_link
                    links={@links}
                    vertex={%Resource{resource: @resource}}
                    label={resource_label(@action, @resource)}
                  />
                  <span :if={@action.type == :action and @action.returns} class="ov-phrase">
                    <span class="ov-muted">returning</span>
                    <.ash_type links={@links} type={@action.returns} />
                  </span>
                </span>
              </:headline>
              <.description links={@links} text={description_of(@action)} lead />
            </.hero>

            <.facts>
              <:fact :if={@inputs != []} label="Inputs">
                {length(@inputs)}
                <span class="ov-muted">
                  ({Enum.count(@inputs, & &1.required?)} required)
                </span>
              </:fact>
              <:fact :if={@runs} label="Runs">
                <.vertex_link :if={@runs.vertex} links={@links} vertex={@runs.vertex} />
                <code :if={!@runs.vertex} class="ov-code">{inspect(@runs.module)}</code>
              </:fact>
              <:fact :if={filter(@action)} label="Filter">
                <code class="ov-code">{filter(@action)}</code>
              </:fact>
              <:fact :if={List.wrap(Map.get(@action, :get_by)) != []} label="Gets by">
                <.code_list names={@action.get_by |> List.wrap() |> Enum.map(&to_string/1)} />
              </:fact>
              <:fact :if={pagination(@action)} label="Pagination">{pagination(@action)}</:fact>
              <:fact :if={Map.get(@action, :upsert_identity)} label="Upsert on">
                <code class="ov-code">{@action.upsert_identity}</code>
              </:fact>
              <:fact :if={Map.get(@action, :manual)} label="Manual">
                <code class="ov-code">{implementation(@action.manual)}</code>
              </:fact>
              <:fact :if={Map.get(@action, :timeout)} label="Timeout">{@action.timeout} ms</:fact>
              <:fact :if={Map.has_key?(@action, :require_atomic?)} label="Atomic">
                {if @action.require_atomic?, do: "required", else: "not required"}
              </:fact>
              <:fact label="Transaction">{if @action.transaction?, do: "yes", else: "no"}</:fact>
              <:fact :if={List.wrap(Map.get(@action, :touches_resources)) != []} label="Touches">
                <span class="ov-phrase">
                  <.vertex_link
                    :for={touched <- @action.touches_resources}
                    links={@links}
                    vertex={%Resource{resource: touched}}
                  />
                </span>
              </:fact>
            </.facts>
          </div>

          <.section
            :if={@inputs != []}
            id="inputs"
            title="Inputs"
            icon="attribute"
            tone="data"
            count={length(@inputs)}
          >
            <.overview_table id="action-inputs" rows={@inputs}>
              <:col :let={input} label="Name" class="w-0 whitespace-nowrap">
                <.vertex_link
                  :if={input.vertex}
                  links={@links}
                  vertex={input.vertex}
                  label={input.name}
                  code
                />
                <span :if={!input.vertex} class="ov-link ov-code" {Clarity.Tooltip.attrs("Argument")}>
                  <.type_icon icon="type" tone="neutral" />{input.name}
                </span>
              </:col>
              <:col :let={input} label="Type" class="w-0 whitespace-nowrap">
                <.ash_type links={@links} type={input.type} />
              </:col>
              <:col :let={input} label="About">
                <div class="ov-flags">
                  <.flag :if={input.required?} text="required" />
                  <.flag :if={input.kind == :argument} text="argument" />
                  <.flag :if={input.sensitive?} text="sensitive" />
                  <.flag :if={input.default} hint="The value it takes when none is given">
                    default <code>{input.default}</code>
                  </.flag>
                  <span :if={input.one_of} class="ov-phrase">
                    <span class="ov-muted text-xs">one of</span>
                    <.code_list names={input.one_of} max={8} />
                  </span>
                </div>
                <.description links={@links} text={input.description} class="mt-0.5" />
              </:col>
            </.overview_table>
          </.section>

          <.section
            :if={@steps != []}
            id="steps"
            title="Steps"
            icon="action"
            tone="behaviour"
            count={length(@steps)}
          >
            <ol class="ov-steps">
              <li :for={{kind, call} <- @steps}>
                <.flag text={Atom.to_string(kind)} />
                <code class="ov-code">{call}</code>
              </li>
            </ol>
          </.section>
        </div>
      </div>
      """
    end

    @spec kind(Actions.action()) :: String.t()
    defp kind(%{type: :action}), do: "Generic action"
    defp kind(%{type: type}), do: String.capitalize(to_string(type)) <> " action"

    @spec kind_hint(Actions.action()) :: String.t()
    defp kind_hint(%{type: :create}), do: "Makes a new record"
    defp kind_hint(%{type: :read}), do: "Reads records, changing nothing"
    defp kind_hint(%{type: :update}), do: "Changes a record"
    defp kind_hint(%{type: :destroy}), do: "Removes a record, or marks it removed"
    defp kind_hint(%{type: :action}), do: "Runs logic of its own, and may return a value"

    # What the action does to its resource, as the start of a sentence.
    @spec verb(Actions.action()) :: String.t()
    defp verb(%{type: :create}), do: "Creates a"
    defp verb(%{type: :read, get?: true}), do: "Gets one"
    defp verb(%{type: :read}), do: "Reads"
    defp verb(%{type: :update}), do: "Updates a"
    defp verb(%{type: :destroy, soft?: true}), do: "Archives a"
    defp verb(%{type: :destroy}), do: "Destroys a"
    defp verb(%{type: :action}), do: "Runs on"

    # A read reads many of its resource, unless it gets one.
    @spec resource_label(Actions.action(), module()) :: String.t()
    defp resource_label(%{type: :read, get?: false}, resource),
      do: resource |> Module.split() |> List.last() |> Kernel.<>("s")

    defp resource_label(_action, resource), do: resource |> Module.split() |> List.last()

    # The attributes the action accepts, then its arguments, with which the
    # caller must give.
    @spec inputs(Actions.action(), module()) :: [map()]
    defp inputs(action, resource) do
      require_attributes = List.wrap(Map.get(action, :require_attributes))
      allow_nil_input = List.wrap(Map.get(action, :allow_nil_input))

      accepted =
        for name <- List.wrap(Map.get(action, :accept)),
            attribute = Info.attribute(resource, name),
            attribute != nil do
          %{
            kind: :attribute,
            name: Atom.to_string(name),
            vertex: attribute(resource, attribute),
            type: attribute.type,
            required?:
              name in require_attributes or
                (action.type == :create and not attribute.allow_nil? and
                   is_nil(attribute.default) and name not in allow_nil_input),
            sensitive?: attribute.sensitive?,
            default: default(attribute),
            one_of: one_of(attribute),
            description: description_of(attribute)
          }
        end

      arguments =
        for argument <- Map.get(action, :arguments, []) do
          %{
            kind: :argument,
            name: Atom.to_string(argument.name),
            vertex: nil,
            type: argument.type,
            required?: not argument.allow_nil?,
            sensitive?: Map.get(argument, :sensitive?, false),
            default: default(argument),
            one_of: one_of(argument),
            description: description_of(argument)
          }
        end

      accepted ++ arguments
    end

    # The action's changes, validations and preparations, in order.
    @spec steps(Actions.action()) :: [{:change | :validate | :prepare, String.t()}]
    defp steps(action) do
      changes =
        for change <- Map.get(action, :changes, []) do
          {if(Map.has_key?(change, :validation), do: :validate, else: :change), step(change)}
        end

      preparations =
        for preparation <- Map.get(action, :preparations, []), do: {:prepare, step(preparation)}

      changes ++ preparations
    end

    # What a generic action runs, and the vertex to link it to when it's a
    # Reactor.
    @spec runs(Actions.action()) :: %{module: module(), vertex: struct() | nil} | nil
    defp runs(%{type: :action, run: run}) when run != nil do
      module = implementation_module(run)

      vertex =
        if Reactor.reactor?(module), do: %Reactor{reactor: module}

      %{module: module, vertex: vertex}
    end

    defp runs(_action), do: nil

    @spec implementation_module(term()) :: module()
    defp implementation_module({module, _opts}) when is_atom(module), do: module
    defp implementation_module(module), do: module

    @spec implementation(term()) :: String.t()
    defp implementation(implementation),
      do: implementation |> implementation_module() |> inspect()

    @spec filter(Actions.action()) :: String.t() | nil
    defp filter(%{filter: filter}) when filter != nil, do: inspect(filter)
    defp filter(_action), do: nil

    @spec pagination(Actions.action()) :: String.t() | nil
    defp pagination(%{pagination: %{} = pagination}) do
      [keyset?: "keyset", offset?: "offset"]
      |> Enum.filter(fn {key, _label} -> Map.get(pagination, key) end)
      |> Enum.map_join(" or ", &elem(&1, 1))
      |> case do
        "" -> "yes"
        kinds -> kinds
      end
    end

    defp pagination(_action), do: nil
  end
end
