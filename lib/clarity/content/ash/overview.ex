with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Content.Ash.Overview do
    # What the Ash overview tabs share: how they write types, descriptions,
    # relationships and an action's steps, and the vertices of a resource's
    # fields. The look comes from Clarity.Components.OverviewComponents.
    @moduledoc false

    use Phoenix.Component

    import Clarity.Components.OverviewComponents

    alias Ash.Resource.Calculation.Argument
    alias Ash.Resource.Info
    alias Ash.Resource.Relationships
    alias Clarity.Ash.Expression
    alias Clarity.Content.Ash.StateMachineDiagram
    alias Clarity.Graph
    alias Clarity.Tooltip
    alias Clarity.Vertex.Ash.Action
    alias Clarity.Vertex.Ash.Aggregate
    alias Clarity.Vertex.Ash.Attribute
    alias Clarity.Vertex.Ash.Calculation
    alias Clarity.Vertex.Ash.Relationship
    alias Clarity.Vertex.Ash.Resource
    alias Clarity.Vertex.Ash.Type
    alias Phoenix.LiveView.Rendered

    @doc """
    Renders an Ash type by its short name (`string`, `list of uuid`), linked
    to its page when the graph has one.
    """
    attr :links, :map, required: true
    attr :type, :any, required: true

    @spec ash_type(map()) :: Rendered.t()
    def ash_type(%{type: {:array, inner}} = assigns) do
      assigns = assign(assigns, :type, inner)

      ~H"""
      <span class="ov-type">list of <.ash_type links={@links} type={@type} /></span>
      """
    end

    def ash_type(assigns) do
      vertex = %Type{type: assigns.type}

      assigns =
        assign(assigns,
          name: type_name(assigns.type),
          vertex: if(linked?(assigns.links, vertex), do: vertex)
        )

      ~H"""
      <.vertex_link
        :if={@vertex}
        links={@links}
        vertex={@vertex}
        label={@name}
        icon={false}
        class="ov-type"
      />
      <span :if={!@vertex} class="ov-type">{@name}</span>
      """
    end

    @doc "Returns a type's short name: `string` for `Ash.Type.String`."
    @spec type_name(term()) :: String.t()
    defdelegate type_name(type), to: Type, as: :short_name

    @doc "Returns a description, or `nil` when it's blank."
    @spec description_of(map() | nil) :: String.t() | nil
    def description_of(%{description: description}) when is_binary(description),
      do: if(String.trim(description) != "", do: String.trim(description))

    def description_of(_entity), do: nil

    @doc """
    Returns a module's description: its Ash `description`, else the first
    paragraph of its moduledoc.
    """
    @spec module_description(module(), String.t() | nil) :: String.t() | nil
    def module_description(module, description \\ nil) do
      case description do
        text when is_binary(text) and text != "" ->
          String.trim(text)

        _none ->
          with {:docs_v1, _, _, "text/markdown", %{"en" => moduledoc}, _, _} <-
                 Code.fetch_docs(module),
               [paragraph | _] <- String.split(String.trim(moduledoc), ~r/\n\s*\n/) do
            paragraph
          else
            _no_docs -> nil
          end
      end
    end

    @doc "Returns how many of the other resource a relationship relates to."
    @spec cardinality(Relationships.relationship()) :: String.t()
    def cardinality(%{type: :belongs_to}), do: "belongs to one"
    def cardinality(%{type: :has_one}), do: "has one"
    def cardinality(%{type: :has_many}), do: "has many"
    def cardinality(%{type: :many_to_many}), do: "has many"

    @doc """
    Returns how a calculation computes its value: its expression, or the
    module that implements it.
    """
    @spec computation_of(Ash.Resource.Calculation.t()) :: {:expr, term()} | {:module, module()}
    def computation_of(%{calculation: {Ash.Resource.Calculation.Expression, opts}}),
      do: {:expr, Keyword.get(opts, :expr)}

    def computation_of(%{calculation: {module, _opts}}), do: {:module, module}
    def computation_of(%{calculation: module}) when is_atom(module), do: {:module, module}

    @doc """
    Renders how a calculation on `resource` computes its value: its
    expression, clamped to a couple of lines unless `full`, or its module.
    """
    attr :links, :map, required: true
    attr :resource, :atom, required: true
    attr :calculation, :any, required: true
    attr :full, :boolean, default: false

    @spec computation(map()) :: Rendered.t()
    def computation(assigns) do
      assigns = assign(assigns, :computation, computation_of(assigns.calculation))

      ~H"""
      <%= case @computation do %>
        <% {:expr, expression} -> %>
          <.expression
            links={@links}
            resource={@resource}
            expression={expression}
            arguments={@calculation.arguments}
            block={@full}
            class={!@full && "line-clamp-2"}
          />
        <% {:module, module} -> %>
          <code class="ov-code">{inspect(module)}</code>
      <% end %>
      """
    end

    @doc """
    Renders an expression on `resource` as Ash writes it, with what it names
    linked: each field and relationship to its page, with its hover hint,
    and each of the calculation's `arguments`, and each value from the
    actor, tenant or context, explained on hover.
    """
    attr :links, :map, required: true
    attr :resource, :atom, required: true
    attr :expression, :any, required: true
    attr :arguments, :list, default: [], doc: "The calculation's arguments, it may use"
    attr :block, :boolean, default: false, doc: "Whether it's a block of its own, not inline"
    attr :class, :any, default: nil

    @spec expression(map()) :: Rendered.t()
    def expression(assigns) do
      assigns =
        assign(
          assigns,
          :tokens,
          assigns.resource
          |> Expression.parts(assigns.expression)
          |> Enum.flat_map(&tokens(&1, assigns.links, assigns.arguments))
        )

      ~H"""
      <pre :if={@block} class={["ov-code-block", @class]} phx-no-format><.token :for={token <- @tokens} token={token} links={@links} /></pre>
      <code :if={!@block} class={["ov-code whitespace-pre-wrap", @class]} phx-no-format><.token :for={token <- @tokens} token={token} links={@links} /></code>
      """
    end

    attr :token, :any, required: true
    attr :links, :map, required: true

    @spec token(map()) :: Rendered.t()
    defp token(%{token: {:text, text}} = assigns) do
      assigns = assign(assigns, :text, text)
      ~H"{@text}"
    end

    defp token(%{token: {:link, field, name}} = assigns) do
      assigns = assign(assigns, field: field, name: name)

      ~H|<.link patch={path(@links, @field)} class="ov-expr-ref" {Tooltip.attrs(@field)}>{@name}</.link>|
    end

    defp token(%{token: {:hint, hint, text}} = assigns) do
      assigns = assign(assigns, hint: hint, text: text)
      ~H|<span class="ov-expr-value" {Tooltip.attrs(@hint)}>{@text}</span>|
    end

    # The expression's code as text, links and values explained on hover.
    @spec tokens(Expression.part(), map(), [Argument.t()]) :: [tuple()]
    defp tokens(text, _links, _arguments) when is_binary(text), do: [{:text, text}]

    defp tokens({:ref, %{segments: segments}}, links, _arguments) do
      Enum.map_intersperse(segments, {:text, "."}, fn {name, field} ->
        if field && linked?(links, field), do: {:link, field, name}, else: {:text, name}
      end)
    end

    defp tokens({:argument, name}, _links, arguments),
      do: [{:hint, argument_hint(name, arguments), "^arg(#{inspect(name)})"}]

    defp tokens({:template, "^actor" <> _rest = text}, _links, _arguments),
      do: [{:hint, "From the actor: whoever runs the query", text}]

    defp tokens({:template, "^tenant" <> _rest = text}, _links, _arguments),
      do: [{:hint, "The tenant the query runs for", text}]

    defp tokens({:template, text}, _links, _arguments),
      do: [{:hint, "From the query's context", text}]

    @spec argument_hint(atom(), [Argument.t()]) :: String.t()
    defp argument_hint(name, arguments) do
      case Enum.find(arguments, &(&1.name == name)) do
        nil ->
          "An argument, given when the calculation is loaded"

        argument ->
          "The #{name} argument: #{type_name(argument.type)}" <>
            if(argument.allow_nil?, do: ", optional", else: ", required")
      end
    end

    @doc """
    Returns which visibility to flag among `fields`: whichever is the
    exception, so a resource whose fields are all private doesn't say so on
    every row.
    """
    @spec unusual_visibility([%{public?: boolean()}]) :: :private | :public
    def unusual_visibility(fields) do
      if Enum.count(fields, & &1.public?) * 2 >= length(fields), do: :private, else: :public
    end

    @doc """
    Renders what's notable about an attribute, most important first, and the
    relationship it's the key of, if any.
    """
    attr :attribute, :any, required: true
    attr :unusual, :atom, required: true, doc: "The visibility to flag, see unusual_visibility/1"
    attr :links, :map, default: nil
    attr :key_of, :any, default: nil, doc: "The relationship vertex it's the key of, if any"

    @spec attribute_flags(map()) :: Rendered.t()
    def attribute_flags(assigns) do
      assigns = assign(assigns, :one_of, one_of(assigns.attribute))

      ~H"""
      <div class="ov-flags">
        <span :if={@key_of} class="ov-phrase ov-key-of">
          <span class="ov-muted text-xs">key of</span>
          <.vertex_link
            links={@links}
            vertex={@key_of}
            label={Atom.to_string(@key_of.relationship.name)}
            code
          />
        </span>
        <.flag :if={@attribute.primary_key?} text="primary key" />
        <.flag :if={not @attribute.allow_nil? and not @attribute.primary_key?} text="required" />
        <.flag :if={@attribute.sensitive?} text="sensitive" />
        <.visibility_flag field={@attribute} unusual={@unusual} />
        <.flag :if={@attribute.generated?} text="generated" />
        <.flag :if={not @attribute.writable?} text="read-only" />
        <.flag :if={default(@attribute)} hint="The value it takes when none is given">
          default <code>{default(@attribute)}</code>
        </.flag>
        <span :if={@one_of} class="ov-phrase">
          <span class="ov-muted text-xs">one of</span>
          <.code_list names={@one_of} max={8} />
        </span>
      </div>
      """
    end

    @doc "Returns whether `visibility_flag/1` shows a flag for the field."
    @spec visibility_flagged?(%{public?: boolean()}, :private | :public) :: boolean()
    def visibility_flagged?(field, :private), do: not field.public?
    def visibility_flagged?(field, :public), do: field.public?

    @doc "Renders a field's visibility, when it's the exception among its kind."
    attr :field, :any, required: true
    attr :unusual, :atom, required: true

    @spec visibility_flag(map()) :: Rendered.t()
    def visibility_flag(assigns) do
      ~H"""
      <.flag :if={@unusual == :private and not @field.public?} text="private" />
      <.flag :if={@unusual == :public and @field.public?} text="public" />
      """
    end

    @doc "Returns an attribute's default value, when it's a plain value worth showing."
    @spec default(Ash.Resource.Attribute.t()) :: String.t() | nil
    def default(%{default: default}) when is_function(default) or is_nil(default), do: nil
    def default(%{default: {_module, _function, _args}}), do: nil
    def default(%{default: default}), do: inspect(default)

    @doc "Returns the values an attribute may take, when its constraints list them."
    @spec one_of(Ash.Resource.Attribute.t()) :: [String.t()] | nil
    def one_of(%{constraints: constraints}) when is_list(constraints) do
      case Keyword.get(constraints, :one_of) do
        values when is_list(values) and values != [] -> Enum.map(values, &to_string/1)
        _none -> nil
      end
    end

    def one_of(_attribute), do: nil

    @doc """
    Renders a resource as a card: its name, data layer and what's notable,
    its description in brief, and how many actions, attributes and
    relationships it has.
    """
    attr :links, :map, required: true
    attr :resource, :atom, required: true
    attr :label, :string, required: true

    attr :common_data_layer, :atom,
      default: nil,
      doc: "The data layer most of its siblings use, which the card leaves unsaid"

    @spec resource_card(map()) :: Rendered.t()
    def resource_card(assigns) do
      resource = assigns.resource

      assigns =
        assign(assigns,
          vertex: %Resource{resource: resource},
          description: module_description(resource, Info.description(resource)),
          counts: [
            {"action", "behaviour", length(Info.actions(resource)), "actions"},
            {"attribute", "data", length(Info.attributes(resource)), "attributes"},
            {"relationship", "data", length(Info.relationships(resource)), "relationships"}
          ]
        )

      ~H"""
      <article class="ov-card ov-resource-card">
        <div class="flex items-start gap-1.5">
          <.vertex_link links={@links} vertex={@vertex} label={@label} class="min-w-0" />
          <div class="ov-flags ml-auto justify-end">
            <.resource_badges
              links={@links}
              resource={@resource}
              data_layer?={Info.data_layer(@resource) != @common_data_layer}
            />
          </div>
        </div>
        <.description links={@links} text={@description} small sentence class="mt-1" />
        <div class="ov-card-counts">
          <span
            :for={{icon, tone, count, label} <- @counts}
            :if={count > 0}
            class="inline-flex items-center gap-1"
            {Tooltip.attrs("#{count} #{label}")}
          >
            <.type_icon icon={icon} tone={tone} />{count}
          </span>
        </div>
      </article>
      """
    end

    @doc """
    Renders what's notable about a resource: pills for its state machine,
    policies and data layer, each linking to where it's shown, and flags for
    whether it's multitenant or embedded.
    """
    attr :links, :map, required: true
    attr :resource, :atom, required: true
    attr :data_layer?, :boolean, default: true, doc: "Whether to show its data layer"

    @spec resource_badges(map()) :: Rendered.t()
    def resource_badges(assigns) do
      resource = assigns.resource
      vertex = %Resource{resource: resource}
      policies = policy_count(resource)

      assigns =
        assign(assigns,
          vertex: vertex,
          data_layer: Info.data_layer(resource),
          policies: policies,
          policies_hint:
            "Authorised by #{policies} #{if policies == 1, do: "policy", else: "policies"}: " <>
              "see the Security lens",
          security_path: Path.join([assigns.links.prefix, "security", Clarity.Vertex.id(vertex)]),
          state_machine_path: state_machine_path(assigns.links, vertex),
          multitenancy: multitenancy_hint(resource),
          embedded?: Info.embedded?(resource)
        )

      ~H"""
      <.vertex_pill
        :if={@state_machine_path}
        links={@links}
        vertex={@vertex}
        label="state machine"
        icon="reactor"
        tone="behaviour"
        to={@state_machine_path}
        hint="Moves between states: see its State Machine tab"
      />
      <.vertex_pill
        :if={@policies > 0}
        links={@links}
        vertex={@vertex}
        label="policies"
        icon="policy"
        tone="rule"
        to={@security_path}
        hint={@policies_hint}
      />
      <.vertex_pill
        :if={@data_layer && @data_layer?}
        links={@links}
        vertex={%Clarity.Vertex.Ash.DataLayer{data_layer: @data_layer}}
        label={@data_layer |> Module.split() |> List.last()}
      />
      <.flag :if={@multitenancy} text="multitenant" hint={@multitenancy} />
      <.flag :if={@embedded?} text="embedded" />
      """
    end

    @doc "Returns the data layer most of `resources` use."
    @spec common_data_layer([module()]) :: module() | nil
    def common_data_layer([]), do: nil

    def common_data_layer(resources) do
      resources
      |> Enum.frequencies_by(&Info.data_layer/1)
      |> Enum.max_by(&elem(&1, 1))
      |> elem(0)
    end

    @spec policy_count(module()) :: non_neg_integer()
    defp policy_count(resource) do
      if Ash.Policy.Authorizer in Info.authorizers(resource),
        do: length(Ash.Policy.Info.policies(resource)),
        else: 0
    end

    # The resource's State Machine tab, when it has a state machine.
    @spec state_machine_path(map(), Clarity.Vertex.t()) :: String.t() | nil
    defp state_machine_path(links, %{resource: resource} = vertex) do
      with true <- AshStateMachine in Spark.extensions(resource),
           true <- Code.ensure_loaded?(StateMachineDiagram) do
        Path.join([
          links.prefix,
          links.lens.id,
          Clarity.Vertex.id(vertex),
          Clarity.Content.content_id(StateMachineDiagram)
        ])
      else
        _no_state_machine -> nil
      end
    end

    @spec multitenancy_hint(module()) :: String.t() | nil
    defp multitenancy_hint(resource) do
      case Info.multitenancy_strategy(resource) do
        nil ->
          nil

        :attribute ->
          "Keeps each tenant's records apart, by its " <>
            "#{Info.multitenancy_attribute(resource)} attribute"

        :context ->
          "Keeps each tenant's records apart, in the data layer"
      end
    end

    @doc """
    Writes an action's change, preparation or validation as a call:
    `set_attribute(attribute: :status, value: :closed)`.
    """
    @spec step(term()) :: String.t()
    def step(%{change: change}), do: step(change)
    def step(%{preparation: preparation}), do: step(preparation)
    def step(%{validation: validation}), do: step(validation)
    def step({module, opts}) when is_atom(module), do: call(module, opts)
    def step(module) when is_atom(module), do: call(module, [])
    def step(other), do: inspect(other)

    @spec call(module(), keyword() | term()) :: String.t()
    defp call(module, opts) do
      name = module |> Module.split() |> List.last() |> Macro.underscore()

      args =
        if is_list(opts) and opts != [] and Keyword.keyword?(opts),
          do: Enum.map_join(opts, ", ", fn {key, value} -> "#{key}: #{inspect(value)}" end),
          else: ""

      "#{name}(#{args})"
    end

    @doc "Returns the vertex of a resource's attribute, action or other field."
    @spec attribute(module(), Ash.Resource.Attribute.t()) :: Attribute.t()
    def attribute(resource, attribute), do: %Attribute{attribute: attribute, resource: resource}

    @spec relationship(module(), Relationships.relationship()) :: Relationship.t()
    def relationship(resource, relationship),
      do: %Relationship{relationship: relationship, resource: resource}

    @spec action(module(), Ash.Resource.Actions.action()) :: Action.t()
    def action(resource, action), do: %Action{action: action, resource: resource}

    @spec aggregate(module(), Ash.Resource.Aggregate.t()) :: Aggregate.t()
    def aggregate(resource, aggregate), do: %Aggregate{aggregate: aggregate, resource: resource}

    @spec calculation(module(), Ash.Resource.Calculation.t()) :: Calculation.t()
    def calculation(resource, calculation),
      do: %Calculation{calculation: calculation, resource: resource}

    @doc "Returns the attribute vertex a resource's field name names, if any."
    @spec attribute_named(module(), atom()) :: Attribute.t() | nil
    def attribute_named(resource, name) do
      case Info.attribute(resource, name) do
        nil -> nil
        attribute -> attribute(resource, attribute)
      end
    end

    # Whether the overview's graph has the vertex, so a link to it goes
    # somewhere; without a graph, every link is kept.
    @spec linked?(map(), Clarity.Vertex.t()) :: boolean()
    defp linked?(%{graph: nil}, _vertex), do: true

    defp linked?(%{graph: graph}, vertex),
      do: Graph.get_vertex(graph, Clarity.Vertex.id(vertex)) != nil
  end
end
