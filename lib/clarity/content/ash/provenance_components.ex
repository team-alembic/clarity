with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Content.Ash.ProvenanceComponents do
    # Where a calculation's or an aggregate's value comes from, on its
    # overview: a diagram from the stored fields to the value, grouped by
    # resource, and the same as a tree, each field with how it's computed.
    # The fields come from Clarity.Ash.Provenance.
    @moduledoc false

    use Phoenix.Component

    import Clarity.Components.OverviewComponents
    import Clarity.Content.Ash.Overview

    alias Clarity.Ash.Expression
    alias Clarity.Ash.Provenance
    alias Clarity.CoreComponents
    alias Clarity.Graph.DOT
    alias Clarity.Tooltip
    alias Clarity.Vertex
    alias Clarity.Vertex.Ash.Aggregate
    alias Clarity.Vertex.Ash.Attribute
    alias Clarity.Vertex.Ash.Calculation
    alias Clarity.Vertex.Ash.Relationship
    alias Phoenix.LiveView.Rendered

    @doc """
    Renders where a field's value comes from: a diagram, when the value
    comes by more than one step or from another resource, and a tree. Nothing
    when it reads no other field.
    """
    attr :links, :map, required: true
    attr :tree, :map, required: true, doc: "From `Clarity.Ash.Provenance.of/1`"
    attr :theme, :atom, default: :light

    @spec provenance(map()) :: Rendered.t()
    def provenance(assigns) do
      {fields, edges} = Provenance.flatten(assigns.tree)
      stored = Enum.filter(fields, &match?(%Attribute{}, &1))
      resources = fields |> Enum.map(& &1.resource) |> Enum.uniq()

      assigns =
        assign(assigns,
          fields: fields,
          stored: length(stored),
          resources: length(resources),
          diagram:
            if(Enum.any?(assigns.tree.children, &(&1.children != [])) or length(resources) > 1,
              do: assigns.tree |> diagram(fields, edges, assigns.theme) |> IO.iodata_to_binary()
            )
        )

      ~H"""
      <.section
        :if={@tree.children != []}
        id="provenance"
        title="Where its value comes from"
        icon="attribute"
        tone="data"
      >
        <:aside :if={@stored > 0}>
          <span class="ov-muted">
            {plural(@stored, "stored field")}{if @resources > 1,
              do: " on #{@resources} resources"}
          </span>
        </:aside>
        <CoreComponents.viz
          :if={@diagram}
          id="provenance-diagram"
          graph={@diagram}
          tooltips={Tooltip.hints(@fields)}
          data-pan-zoom="false"
          data-event="viz:open"
          class="ov-diagram"
        />
        <ul class="ov-sources">
          <.source :for={node <- @tree.children} node={node} links={@links} />
        </ul>
      </.section>
      """
    end

    attr :node, :map, required: true
    attr :links, :map, required: true

    @spec source(map()) :: Rendered.t()
    defp source(assigns) do
      ~H"""
      <li>
        <div class="ov-source">
          <span class="ov-source-name" phx-no-format><%= for hop <- @node.via do %><.vertex_link links={@links} vertex={hop} label={Atom.to_string(hop.relationship.name)} icon={false} code />.<% end %><.vertex_link links={@links} vertex={@node.vertex} label={name(@node.vertex)} code /></span>
          <.what links={@links} vertex={@node.vertex} />
          <.flag :if={@node.role == :filters} text="filter" />
          <span
            :if={@node.repeat?}
            class="ov-muted"
            {Tooltip.attrs("Where its value comes from is shown above")}
          >
            as above
          </span>
        </div>
        <.how :if={not @node.repeat?} links={@links} vertex={@node.vertex} />
        <ul :if={@node.children != []} class="ov-sources">
          <.source :for={node <- @node.children} node={node} links={@links} />
        </ul>
      </li>
      """
    end

    attr :vertex, :any, required: true
    attr :links, :map, required: true

    # What the field is: its type, and whether it's stored or computed.
    @spec what(map()) :: Rendered.t()
    defp what(%{vertex: %Attribute{attribute: attribute}} = assigns) do
      assigns = assign(assigns, :type, attribute.type)

      ~H"""
      <.ash_type links={@links} type={@type} />
      <.flag text="stored" />
      """
    end

    defp what(%{vertex: %Calculation{calculation: calculation}} = assigns) do
      assigns = assign(assigns, :type, calculation.type)

      ~H"""
      <.ash_type links={@links} type={@type} />
      """
    end

    defp what(%{vertex: %Aggregate{aggregate: aggregate}} = assigns) do
      assigns = assign(assigns, aggregate: aggregate)

      ~H"""
      <span class="ov-phrase">
        <b>{@aggregate.kind}</b>
        <span class="ov-muted">of</span>
        <code class="ov-code">{aggregate_target(@aggregate)}</code>
      </span>
      """
    end

    defp what(%{vertex: %Relationship{relationship: relationship}} = assigns) do
      assigns = assign(assigns, relationship: relationship)

      ~H"""
      <span class="ov-muted">{cardinality(@relationship)}</span>
      <.vertex_link
        links={@links}
        vertex={%Clarity.Vertex.Ash.Resource{resource: @relationship.destination}}
      />
      """
    end

    # How a computed field gets its value: a calculation's expression or
    # module, or the filter an aggregate reads its records by.
    @spec how(map()) :: Rendered.t()
    defp how(%{vertex: %Calculation{calculation: calculation, resource: resource}} = assigns) do
      assigns =
        assign(assigns,
          calculation: calculation,
          resource: resource,
          computation: computation_of(calculation)
        )

      ~H"""
      <div class="ov-source-how">
        <%= case @computation do %>
          <% {:expr, expression} -> %>
            <.expression
              links={@links}
              resource={@resource}
              expression={expression}
              arguments={@calculation.arguments}
            />
          <% {:module, module} -> %>
            <span class="ov-muted">by</span> <code class="ov-code">{inspect(module)}</code>
        <% end %>
      </div>
      """
    end

    defp how(%{vertex: %Aggregate{aggregate: %{filter: filter}} = vertex} = assigns)
         when filter not in [nil, true, []] do
      {_via, destination} = Provenance.records(vertex.resource, vertex.aggregate)
      assigns = assign(assigns, filter: filter, destination: destination)

      ~H"""
      <div :if={@destination} class="ov-source-how">
        <span class="ov-muted">where</span>
        <.expression links={@links} resource={@destination} expression={@filter} />
      </div>
      """
    end

    defp how(assigns), do: ~H""

    @doc """
    Returns the DOT diagram of where a field's value comes from: each field
    a node in a box for its resource, with edges from the fields read to the
    field reading them, so the stored fields are on the left and the value
    on the right.
    """
    @spec diagram(Provenance.tree(), [Expression.field()], list(), DOT.theme()) :: iodata()
    def diagram(tree, fields, edges, theme) do
      [
        "digraph {\n",
        DOT.themed(theme),
        "  graph [rankdir = LR, nodesep = 0.25, ranksep = 0.6, fontsize = 10, fontname = Helvetica];\n",
        "  node [fontsize = 11, fontname = Helvetica, margin = \"0.15,0.05\", height = 0.3];\n",
        "  edge [fontsize = 9, fontname = Helvetica, arrowsize = 0.6];\n",
        fields
        |> Enum.group_by(& &1.resource)
        |> Enum.map(fn {resource, fields} ->
          [
            "  subgraph ",
            DOT.quote_id(["cluster_", inspect(resource)]),
            " {\n",
            "    label = ",
            DOT.html_label(
              Vertex.Name.display(%Clarity.Vertex.Ash.Resource{resource: resource}, :short)
            ),
            ";\n",
            "    style = rounded;\n",
            Enum.map(fields, &node(&1, &1 == tree.vertex, theme)),
            "  }\n"
          ]
        end),
        Enum.map(edges, &edge/1),
        "}\n"
      ]
    end

    @spec node(Expression.field(), boolean(), DOT.theme()) :: iodata()
    defp node(field, root?, theme) do
      [
        "    ",
        DOT.quote_id(Vertex.id(field)),
        " [label = ",
        DOT.html_label([
          Phoenix.HTML.raw("<FONT POINT-SIZE=\"8\"><I>"),
          kind(field),
          Phoenix.HTML.raw("</I></FONT><BR />"),
          name(field)
        ]),
        ", shape = ",
        shape(field),
        ", URL = \"#",
        Vertex.id(field),
        "\"",
        if(root?, do: [", ", DOT.highlighted(theme)], else: ""),
        "];\n"
      ]
    end

    @spec edge({Expression.field(), Expression.field(), [Relationship.t()], Provenance.role()}) ::
            iodata()
    defp edge({from, to, via, role}) do
      label =
        [
          Enum.map_join(via, ".", &Atom.to_string(&1.relationship.name)),
          role == :filters && "filter"
        ]
        |> Enum.reject(&(&1 in [nil, false, ""]))
        |> Enum.join(" · ")

      [
        "  ",
        DOT.quote_id(Vertex.id(from)),
        " -> ",
        DOT.quote_id(Vertex.id(to)),
        " [",
        if(label == "", do: "", else: ["label = ", DOT.html_label(label), ", "]),
        if(role == :filters, do: "style = dashed", else: "style = solid"),
        "];\n"
      ]
    end

    @spec kind(Expression.field()) :: String.t()
    defp kind(%Attribute{}), do: "stored"
    defp kind(%Calculation{}), do: "calculation"
    defp kind(%Aggregate{aggregate: aggregate}), do: Atom.to_string(aggregate.kind)
    defp kind(%Relationship{}), do: "relationship"

    @spec shape(Expression.field()) :: String.t()
    defp shape(%Attribute{}), do: "cylinder"
    defp shape(%Relationship{}), do: "rarrow"
    defp shape(_field), do: "box, style = \"rounded,filled\", fillcolor = transparent"

    @spec name(Expression.field()) :: String.t()
    defp name(%Attribute{attribute: %{name: name}}), do: Atom.to_string(name)
    defp name(%Calculation{calculation: %{name: name}}), do: Atom.to_string(name)
    defp name(%Aggregate{aggregate: %{name: name}}), do: Atom.to_string(name)
    defp name(%Relationship{relationship: %{name: name}}), do: Atom.to_string(name)

    @spec aggregate_target(Ash.Resource.Aggregate.t()) :: String.t()
    defp aggregate_target(%{related?: false, resource: resource} = aggregate),
      do: Enum.map_join([inspect(resource) | List.wrap(aggregate.field)], ".", &to_string/1)

    defp aggregate_target(aggregate),
      do:
        Enum.map_join(
          aggregate.relationship_path ++ List.wrap(aggregate.field),
          ".",
          &to_string/1
        )

    @spec plural(non_neg_integer(), String.t()) :: String.t()
    defp plural(1, noun), do: "1 #{noun}"
    defp plural(count, noun), do: "#{count} #{noun}s"
  end
end
