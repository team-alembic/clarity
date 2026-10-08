with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Content.Ash.Overview do
    # What the Ash overview tabs share: how they write types, descriptions,
    # relationships and an action's steps, and the vertices of a resource's
    # fields. The look comes from Clarity.Components.OverviewComponents.
    @moduledoc false

    use Phoenix.Component

    import Clarity.Components.OverviewComponents

    alias Ash.Resource.Info
    alias Ash.Resource.Relationships
    alias Clarity.Graph
    alias Clarity.Vertex.Ash.Action
    alias Clarity.Vertex.Ash.Aggregate
    alias Clarity.Vertex.Ash.Attribute
    alias Clarity.Vertex.Ash.Calculation
    alias Clarity.Vertex.Ash.Relationship
    alias Clarity.Vertex.Ash.Type
    alias Phoenix.LiveView.Rendered

    @short_names Map.new(Ash.Type.short_names(), fn {short, module} -> {module, short} end)

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
    def type_name({:array, inner}), do: "list of " <> type_name(inner)

    def type_name(type) when is_map_key(@short_names, type),
      do: Atom.to_string(Map.fetch!(@short_names, type))

    def type_name(type) when is_atom(type),
      do: type |> inspect() |> String.replace_prefix("Ash.Type.", "")

    def type_name(type), do: inspect(type)

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
    @spec computation_of(Ash.Resource.Calculation.t()) ::
            {:expr, String.t()} | {:module, module()}
    def computation_of(%{calculation: {Ash.Resource.Calculation.Expression, opts}}),
      do: {:expr, inspect(Keyword.get(opts, :expr), pretty: true, width: 80)}

    def computation_of(%{calculation: {module, _opts}}), do: {:module, module}
    def computation_of(%{calculation: module}) when is_atom(module), do: {:module, module}

    @doc """
    Renders how a calculation computes its value: its expression, clamped to
    a couple of lines unless `full`, or its module.
    """
    attr :calculation, :any, required: true
    attr :full, :boolean, default: false

    @spec computation(map()) :: Rendered.t()
    def computation(assigns) do
      assigns = assign(assigns, :computation, computation_of(assigns.calculation))

      ~H"""
      <%= case @computation do %>
        <% {:expr, code} -> %>
          <pre :if={@full} class="ov-code-block">{code}</pre>
          <code :if={!@full} class="ov-code line-clamp-2 whitespace-pre-wrap">{code}</code>
        <% {:module, module} -> %>
          <code class="ov-code">{inspect(module)}</code>
      <% end %>
      """
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

    @doc "Renders what's notable about an attribute, most important first."
    attr :attribute, :any, required: true
    attr :unusual, :atom, required: true, doc: "The visibility to flag, see unusual_visibility/1"

    @spec attribute_flags(map()) :: Rendered.t()
    def attribute_flags(assigns) do
      assigns = assign(assigns, :one_of, one_of(assigns.attribute))

      ~H"""
      <div class="ov-flags">
        <.flag :if={@attribute.primary_key?} kind={:key}>primary key</.flag>
        <.flag :if={not @attribute.allow_nil? and not @attribute.primary_key?} kind={:warn}>
          required
        </.flag>
        <.flag :if={@attribute.sensitive?} kind={:danger}>sensitive</.flag>
        <.visibility_flag field={@attribute} unusual={@unusual} />
        <.flag :if={@attribute.generated?} kind={:muted}>generated</.flag>
        <.flag :if={not @attribute.writable?} kind={:muted}>read-only</.flag>
        <.flag :if={default(@attribute)}>default <code>{default(@attribute)}</code></.flag>
        <span :if={@one_of} class="ov-phrase">
          <span class="ov-muted text-xs">one of</span>
          <.code_list names={@one_of} max={8} />
        </span>
      </div>
      """
    end

    @doc "Renders a field's visibility, when it's the exception among its kind."
    attr :field, :any, required: true
    attr :unusual, :atom, required: true

    @spec visibility_flag(map()) :: Rendered.t()
    def visibility_flag(assigns) do
      ~H"""
      <.flag :if={@unusual == :private and not @field.public?} kind={:muted}>private</.flag>
      <.flag :if={@unusual == :public and @field.public?} kind={:good}>public</.flag>
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

    @spec resource_card(map()) :: Rendered.t()
    def resource_card(assigns) do
      resource = assigns.resource

      assigns =
        assign(assigns,
          vertex: %Clarity.Vertex.Ash.Resource{resource: resource},
          data_layer: Info.data_layer(resource),
          state_machine?: AshStateMachine in Spark.extensions(resource),
          policies?: Ash.Policy.Authorizer in Info.authorizers(resource),
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
          <div class="ov-flags ml-auto shrink-0 justify-end">
            <.flag :if={@state_machine?} kind={:good}>state machine</.flag>
            <.flag :if={@policies?}>policies</.flag>
            <.flag :if={@data_layer} kind={:muted}>
              {@data_layer |> Module.split() |> List.last()}
            </.flag>
          </div>
        </div>
        <.description links={@links} text={@description} small class="mt-1 line-clamp-2" />
        <div class="ov-card-counts">
          <span
            :for={{icon, tone, count, label} <- @counts}
            :if={count > 0}
            class="inline-flex items-center gap-1"
            {Clarity.Tooltip.attrs("#{count} #{label}")}
          >
            <.type_icon icon={icon} tone={tone} />{count}
          </span>
        </div>
      </article>
      """
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
