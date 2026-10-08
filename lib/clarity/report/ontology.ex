with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Report.Ontology do
    @moduledoc """
    Ontology report: the domain vocabulary declared by the project's Ash
    resources — every entity (resource) and the terms it defines (attributes,
    calculations, aggregates, and relationships), with names, types,
    constraints and descriptions read from the code, so always in sync.
    Actions are left out: they are verbs, and this is a dictionary of nouns.

    Its actions (`actions/2`) are the documentation to write: resources
    without a description, and terms without one, private ones included.
    """

    @behaviour Clarity.Report

    use Clarity.Web, :live_component

    import Clarity.Components.MarkdownComponent

    alias Ash.Resource.Info
    alias Ash.Resource.Relationships
    alias Clarity.Autolink
    alias Clarity.Graph
    alias Clarity.Report.Action
    alias Clarity.Report.Charts
    alias Clarity.Report.Components
    alias Clarity.Vertex
    alias Clarity.Vertex.Ash.Aggregate
    alias Clarity.Vertex.Ash.Attribute
    alias Clarity.Vertex.Ash.Calculation
    alias Clarity.Vertex.Ash.Relationship
    alias Clarity.Vertex.Ash.Resource
    alias Clarity.Vertex.Ash.Type
    alias Clarity.Vertex.Util
    alias Phoenix.LiveView.Rendered

    @kind_order [:attribute, :calculation, :aggregate, :relationship]

    @typep term_kind() :: :attribute | :calculation | :aggregate | :relationship

    # Rich text for a cell: plain text, a link to a vertex, or code.
    @typep segment() :: String.t() | {:link, String.t(), String.t()} | {:code, String.t()}

    # A note on a term: a flag (tinted by tone), or the members of an enum.
    @typep note() :: {:flag, String.t(), atom()} | {:one_of, [atom()]}

    @typep term_entry() :: %{
             required(:kind) => term_kind(),
             required(:name) => String.t(),
             required(:fqn) => String.t(),
             required(:id) => String.t(),
             required(:linked?) => boolean(),
             required(:type) => [segment()],
             required(:description) => String.t() | nil,
             required(:notes) => [note()]
           }

    @typep gap() :: %{required(:name) => String.t(), required(:private?) => boolean()}

    @typep entity() :: %{
             required(:name) => String.t(),
             required(:module) => module(),
             required(:id) => String.t(),
             required(:domain) => module() | nil,
             required(:moduledoc) => String.t() | nil,
             required(:data_layer) => String.t(),
             required(:terms) => [term_entry()],
             required(:undocumented) => [gap()]
           }

    @impl Clarity.Report
    def name, do: "Ontology"

    @impl Clarity.Report
    def description, do: "The domain vocabulary: entities, terms, and documentation coverage"

    @impl Clarity.Report
    def category, do: "Architecture"

    @impl Clarity.Report
    def actions(graph, opts) do
      name_style = Keyword.get(opts, :name_style, :qualified)
      entities = entities(graph)
      undescribed = Enum.filter(entities, &(&1.moduledoc == nil))

      gaps =
        entities
        |> Enum.reject(&(&1.undocumented == []))
        |> Enum.sort_by(&(-length(&1.undocumented)))

      Enum.reject(
        [
          undescribed != [] &&
            %Action{
              severity: :medium,
              title: "Resources without a description",
              hint: "A resource's description is the first paragraph of its @moduledoc.",
              fix: "Add a `@moduledoc` saying what each one is.",
              groups: [
                %{items: Enum.map(undescribed, &%{text: todo_name(&1, name_style), id: &1.id})}
              ]
            },
          gaps != [] &&
            %Action{
              severity: :low,
              title: "Terms without a description",
              hint:
                "Every undocumented attribute, calculation, aggregate and relationship, private ones (faded) included; most first.",
              fix: ~s(Add `description "…"` to each.),
              groups:
                for entity <- gaps do
                  %{
                    label: todo_name(entity, name_style),
                    id: entity.id,
                    items:
                      Enum.map(entity.undocumented, fn gap ->
                        %{
                          text: gap.name,
                          muted?: gap.private?,
                          hint: if(gap.private?, do: "Private")
                        }
                      end)
                  }
                end
            }
        ],
        &(&1 == false)
      )
    end

    @impl Phoenix.LiveComponent
    def update(assigns, socket) do
      entities = entities(assigns.graph)
      linking = Map.get(assigns, :linking, [])
      terms = Enum.flat_map(entities, & &1.terms)

      {:ok,
       assign(socket,
         prefix: assigns.prefix,
         lens: assigns.lens,
         graph: assigns.graph,
         entities: entities,
         name_style: Map.get(assigns, :name_style, :qualified),
         # Built once for every description the report renders.
         index: Autolink.index(assigns.graph, linking),
         linking: linking,
         terms: length(terms),
         documented: Enum.count(terms, &(&1.description != nil))
       )}
    end

    @impl Phoenix.LiveComponent
    def render(assigns) do
      ~H"""
      <section class="space-y-6">
        <p :if={@entities == []} class="report-status-meta">No Ash resources found.</p>

        <div :if={@entities != []} class="space-y-4">
          <div class="grid grid-cols-2 gap-2 sm:grid-cols-4">
            <Charts.stat label="Entities" value={length(@entities)} />
            <Charts.stat label="Public terms" value={@terms} />
            <Charts.stat label="Documented" value={@documented} tone={:ok} />
            <Charts.stat
              label="Undocumented"
              value={@terms - @documented}
              tone={if(@terms > @documented, do: :warning, else: :ok)}
            />
          </div>
          <Charts.stacked_bar
            title="Documentation coverage"
            segments={[
              %{label: "Documented", value: @documented, tone: :ok},
              %{label: "Undocumented", value: @terms - @documented, tone: :warning}
            ]}
          />
        </div>

        <Components.section
          :if={@entities != []}
          id="entities"
          title="Entities"
          count={length(@entities)}
        >
          <table class="report-table">
            <thead>
              <tr>
                <th class="min-w-36">Entity</th>
                <th>Domain</th>
                <th class="min-w-32">Description</th>
                <th>Data layer</th>
                <th>Documented</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={entity <- @entities}>
                <td>
                  <Components.vertex_link graph={@graph} prefix={@prefix} lens={@lens} id={entity.id}>
                    <Components.dotted name={entity_name(entity, @name_style)} />
                  </Components.vertex_link>
                </td>
                <td><Components.dotted name={domain_name(entity.domain, @name_style)} /></td>
                <td>
                  <.description
                    text={entity.moduledoc}
                    entity={entity}
                    prefix={@prefix}
                    lens={@lens}
                    index={@index}
                    linking={@linking}
                  />
                </td>
                <td><Components.dotted name={entity.data_layer} /></td>
                <td class="whitespace-nowrap"><.coverage terms={entity.terms} /></td>
              </tr>
            </tbody>
          </table>
        </Components.section>

        <Components.section :if={@entities != []} id="terms" title="Terms" count={@terms}>
          <div class="-my-4">
            <Components.section
              :for={entity <- @entities}
              id={"terms-#{entity.id}"}
              title={entity.name}
              count={length(entity.terms)}
            >
              <table class="report-table">
                <thead>
                  <tr>
                    <th class="min-w-40">Term</th>
                    <th>Kind</th>
                    <th>Type</th>
                    <th class="min-w-32">Description</th>
                    <th class="min-w-28">Notes</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={term <- entity.terms}>
                    <td>
                      <Components.vertex_link
                        :if={term.linked?}
                        graph={@graph}
                        prefix={@prefix}
                        lens={@lens}
                        id={term.id}
                      >
                        <Components.dotted name={term_name(term, @name_style)} />
                      </Components.vertex_link>
                      <span :if={!term.linked?} class="font-medium">
                        <Components.dotted name={term_name(term, @name_style)} />
                      </span>
                    </td>
                    <td><span class="report-tag">{term.kind}</span></td>
                    <td>
                      <.segments segments={term.type} graph={@graph} prefix={@prefix} lens={@lens} />
                    </td>
                    <td>
                      <.description
                        text={term.description}
                        entity={entity}
                        prefix={@prefix}
                        lens={@lens}
                        index={@index}
                        linking={@linking}
                      />
                    </td>
                    <td><.notes notes={term.notes} /></td>
                  </tr>
                </tbody>
              </table>
            </Components.section>
          </div>
        </Components.section>
      </section>
      """
    end

    attr :text, :any, required: true
    attr :entity, :map, required: true
    attr :prefix, :string, required: true
    attr :lens, :any, required: true
    attr :index, :any, required: true
    attr :linking, :list, required: true

    # A description, its names linked as in any text about the entity; or a
    # flag where there is none.
    @spec description(map()) :: Rendered.t()
    defp description(%{text: nil} = assigns) do
      ~H|<span class="report-tag" data-tone="warning">undocumented</span>|
    end

    defp description(assigns) do
      ~H"""
      <.markdown
        content={@text}
        prefix={@prefix}
        lens={@lens}
        index={@index}
        vertex={%Resource{resource: @entity.module}}
        linking={@linking}
      />
      """
    end

    attr :segments, :list, required: true
    attr :graph, :any, required: true
    attr :prefix, :string, required: true
    attr :lens, :any, required: true

    @spec segments(map()) :: Rendered.t()
    defp segments(assigns) do
      ~H"""
      <span>
        <%= for segment <- @segments do %>
          <%= case segment do %>
            <% {:link, text, id} -> %>
              <Components.vertex_link graph={@graph} prefix={@prefix} lens={@lens} id={id}>{text}</Components.vertex_link>
            <% {:code, text} -> %>
              <code>{text}</code>
            <% text -> %>
              {text}
          <% end %>
        <% end %>
      </span>
      """
    end

    attr :notes, :list, required: true

    @spec notes(map()) :: Rendered.t()
    defp notes(assigns) do
      ~H"""
      <span :if={@notes == []} class="report-muted">—</span>
      <span :if={@notes != []} class="flex flex-wrap items-center gap-1">
        <%= for note <- @notes do %>
          <%= case note do %>
            <% {:flag, label, tone} -> %>
              <span class="report-tag" data-tone={tone}>{label}</span>
            <% {:one_of, members} -> %>
              <span class="report-muted text-xs">one of</span>
              <Components.chip :for={member <- members}>{inspect(member)}</Components.chip>
          <% end %>
        <% end %>
      </span>
      """
    end

    attr :terms, :list, required: true

    @spec coverage(map()) :: Rendered.t()
    defp coverage(assigns) do
      assigns =
        assign(assigns,
          total: length(assigns.terms),
          documented: Enum.count(assigns.terms, &(&1.description != nil))
        )

      ~H"""
      <span class="inline-flex items-center gap-2 tabular-nums">
        <span class="report-meter" aria-hidden="true">
          <span style={"width: #{if @total == 0, do: 100, else: round(@documented / @total * 100)}%"} />
        </span>
        {@documented}/{@total}
      </span>
      """
    end

    # Data gathering

    @spec entities(Graph.t()) :: [entity()]
    defp entities(graph) do
      linked_ids = linked_vertex_ids(graph)

      graph
      |> Graph.vertices({:==, :vertex_type, Resource})
      |> Enum.map(&entity(&1, linked_ids))
      |> Enum.sort_by(& &1.name)
    end

    # Ids of the resource, term, and type vertices in the graph — only these
    # become links, so the report never links to a vertex that isn't there.
    @spec linked_vertex_ids(Graph.t()) :: MapSet.t(String.t())
    defp linked_vertex_ids(graph) do
      graph
      |> Graph.vertices({:in, :vertex_type, term_vertex_types()})
      |> MapSet.new(&Vertex.id/1)
    end

    @spec term_vertex_types() :: [module()]
    defp term_vertex_types do
      [
        Resource,
        Attribute,
        Calculation,
        Aggregate,
        Relationship,
        Type
      ]
    end

    @spec entity(Resource.t(), MapSet.t(String.t())) :: entity()
    defp entity(%Resource{resource: resource}, linked_ids) do
      %{
        name: inspect(resource),
        module: resource,
        id: Util.id(Resource, [resource]),
        domain: Info.domain(resource),
        moduledoc: moduledoc(resource),
        data_layer:
          resource
          |> Info.data_layer()
          |> inspect()
          |> String.replace_prefix("Ash.DataLayer.", ""),
        terms: terms(resource, linked_ids),
        undocumented: undocumented_terms(resource)
      }
    end

    # The dictionary lists public terms only; the to-do counts every
    # undocumented term, private ones included.
    @spec terms(Ash.Resource.t(), MapSet.t(String.t())) :: [term_entry()]
    defp terms(resource, linked_ids) do
      [
        attribute_terms(resource, linked_ids),
        calculation_terms(resource, linked_ids),
        aggregate_terms(resource, linked_ids),
        relationship_terms(resource, linked_ids)
      ]
      |> Enum.concat()
      |> Enum.sort_by(fn term -> {kind_index(term.kind), term.name} end)
    end

    @spec attribute_terms(Ash.Resource.t(), MapSet.t(String.t())) :: [term_entry()]
    defp attribute_terms(resource, linked_ids) do
      for attribute <- Info.attributes(resource), attribute.public? do
        term(
          :attribute,
          resource,
          attribute.name,
          format_type(attribute.type, linked_ids),
          attribute.description,
          attribute_notes(attribute),
          linked_ids
        )
      end
    end

    @spec calculation_terms(Ash.Resource.t(), MapSet.t(String.t())) :: [term_entry()]
    defp calculation_terms(resource, linked_ids) do
      for calculation <- Info.calculations(resource), calculation.public? do
        term(
          :calculation,
          resource,
          calculation.name,
          format_type(calculation.type, linked_ids),
          calculation.description,
          [],
          linked_ids
        )
      end
    end

    @spec aggregate_terms(Ash.Resource.t(), MapSet.t(String.t())) :: [term_entry()]
    defp aggregate_terms(resource, linked_ids) do
      for aggregate <- Info.aggregates(resource), aggregate.public? do
        term(
          :aggregate,
          resource,
          aggregate.name,
          format_type(Aggregate.value_type(resource, aggregate), linked_ids),
          aggregate.description,
          [],
          linked_ids
        )
      end
    end

    @spec relationship_terms(Ash.Resource.t(), MapSet.t(String.t())) :: [term_entry()]
    defp relationship_terms(resource, linked_ids) do
      for relationship <- Info.relationships(resource), Map.get(relationship, :public?, false) do
        term(
          :relationship,
          resource,
          relationship.name,
          relationship_type(relationship, linked_ids),
          Map.get(relationship, :description),
          relationship_notes(relationship),
          linked_ids
        )
      end
    end

    @spec term(
            term_kind(),
            Ash.Resource.t(),
            atom(),
            [segment()],
            String.t() | nil,
            [note()],
            MapSet.t(String.t())
          ) ::
            term_entry()
    defp term(kind, resource, name, type, description, notes, linked_ids) do
      id = Util.id(vertex_module(kind), [resource, name])

      %{
        kind: kind,
        name: Atom.to_string(name),
        fqn: "#{inspect(resource)}.#{name}",
        id: id,
        linked?: MapSet.member?(linked_ids, id),
        type: type,
        description: normalize_description(description),
        notes: notes
      }
    end

    @spec undocumented_terms(Ash.Resource.t()) :: [gap()]
    defp undocumented_terms(resource) do
      [
        Info.attributes(resource),
        Info.calculations(resource),
        Info.aggregates(resource),
        Info.relationships(resource)
      ]
      |> Enum.concat()
      |> Enum.filter(&undocumented?(&1.description))
      |> Enum.map(fn term ->
        %{
          name: Atom.to_string(term.name),
          private?: not Map.get(term, :public?, false)
        }
      end)
      |> Enum.sort_by(&{&1.private?, &1.name})
    end

    @spec undocumented?(term()) :: boolean()
    defp undocumented?(nil), do: true

    defp undocumented?(description) when is_binary(description),
      do: String.trim(description) == ""

    defp undocumented?(_description), do: false

    # Names

    # With short names, domains are named within the application, and
    # entities within their domain; terms sit under their entity's heading,
    # so need no resource.
    @spec domain_name(module() | nil, Vertex.Name.style()) :: String.t()
    defp domain_name(nil, _name_style), do: "—"
    defp domain_name(domain, :short), do: Vertex.Name.in_app(domain)
    defp domain_name(domain, _name_style), do: inspect(domain)

    @spec entity_name(entity(), Vertex.Name.style()) :: String.t()
    defp entity_name(%{domain: domain, module: module}, :short) when domain != nil,
      do: Vertex.Name.within(module, domain)

    defp entity_name(entity, _name_style), do: entity.name

    # In a to-do nothing beside a resource says which domain holds it, so a
    # short name keeps its domain (Helpdesk.Ticket, Projects.Ticket).
    @spec todo_name(entity(), Vertex.Name.style()) :: String.t()
    defp todo_name(entity, :short), do: Vertex.Name.in_app(entity.module)
    defp todo_name(entity, _name_style), do: entity.name

    @spec term_name(term_entry(), Vertex.Name.style()) :: String.t()
    defp term_name(term, :short), do: term.name
    defp term_name(term, _name_style), do: term.fqn

    # Term helpers

    @spec vertex_module(term_kind()) :: module()
    defp vertex_module(:attribute), do: Attribute
    defp vertex_module(:calculation), do: Calculation
    defp vertex_module(:aggregate), do: Aggregate
    defp vertex_module(:relationship), do: Relationship

    @spec kind_index(term_kind()) :: non_neg_integer() | nil
    defp kind_index(kind), do: Enum.find_index(@kind_order, &(&1 == kind))

    @spec attribute_notes(Ash.Resource.Attribute.t()) :: [note()]
    defp attribute_notes(attribute) do
      Enum.reject(
        [
          attribute.primary_key? && {:flag, "primary key", :neutral},
          attribute.sensitive? && {:flag, "sensitive", :error},
          attribute.allow_nil? == false && {:flag, "required", :neutral},
          one_of_note(attribute.constraints)
        ],
        &(&1 in [nil, false])
      )
    end

    @spec relationship_notes(Relationships.relationship()) :: [note()]
    defp relationship_notes(relationship) do
      if Map.get(relationship, :allow_nil?) == false,
        do: [{:flag, "required", :neutral}],
        else: []
    end

    # An atom type's `one_of` members are themselves vocabulary, so an enum's
    # values are spelled out (an array attribute's item vocabulary too).
    @spec one_of_note(term()) :: note() | nil
    defp one_of_note(constraints) do
      case constraint_members(constraints) do
        [] -> nil
        members -> {:one_of, members}
      end
    end

    @spec constraint_members(term()) :: [atom()]
    defp constraint_members(constraints) when is_map(constraints) do
      one_of_members(constraints) ++ one_of_members(Map.get(constraints, :items))
    end

    defp constraint_members(constraints) when is_list(constraints) do
      one_of_members(constraints) ++ one_of_members(Keyword.get(constraints, :items))
    end

    defp constraint_members(_constraints), do: []

    @spec one_of_members(term()) :: [atom()]
    defp one_of_members(constraints) when is_map(constraints),
      do: List.wrap(Map.get(constraints, :one_of))

    defp one_of_members(constraints) when is_list(constraints),
      do: List.wrap(Keyword.get(constraints, :one_of))

    defp one_of_members(_constraints), do: []

    # A relationship's type is the sentence it states, with the cardinality
    # in words.
    @spec relationship_type(Relationships.relationship(), MapSet.t(String.t())) :: [segment()]
    defp relationship_type(relationship, linked_ids) do
      [
        cardinality_phrase(relationship),
        destination(relationship.destination, linked_ids)
        | through_suffix(relationship)
      ]
    end

    @spec cardinality_phrase(Relationships.relationship()) :: String.t()
    defp cardinality_phrase(%{type: :belongs_to}), do: "belongs to one "
    defp cardinality_phrase(%{type: :has_one}), do: "has one "
    defp cardinality_phrase(%{type: :has_many}), do: "has many "
    defp cardinality_phrase(%{type: :many_to_many}), do: "has many "

    @spec destination(module(), MapSet.t(String.t())) :: segment()
    defp destination(destination, linked_ids) do
      id = Util.id(Resource, [destination])

      if MapSet.member?(linked_ids, id),
        do: {:link, inspect(destination), id},
        else: {:code, inspect(destination)}
    end

    @spec through_suffix(Relationships.relationship()) :: [segment()]
    defp through_suffix(%{type: :many_to_many, through: through}),
      do: [" through ", {:code, inspect(through)}]

    defp through_suffix(_relationship), do: []

    # A type links through to its `Vertex.Ash.Type` page when the graph has
    # one (custom types and embedded resources), so the vocabulary of the
    # value types stays part of the ontology.
    @spec format_type(term(), MapSet.t(String.t())) :: [segment()]
    defp format_type({:array, inner_type}, linked_ids) do
      ["list of " | format_type(inner_type, linked_ids)]
    end

    defp format_type(type, linked_ids) when is_atom(type) do
      type_name =
        type
        |> to_string()
        |> String.replace_prefix("Elixir.", "")
        |> String.replace_prefix("Ash.Type.", "")

      id = Util.id(Type, [type])

      if MapSet.member?(linked_ids, id), do: [{:link, type_name, id}], else: [type_name]
    end

    defp format_type(type, _linked_ids), do: [{:code, inspect(type)}]

    # The first paragraph of the resource's moduledoc, as a one-line summary.
    @spec moduledoc(module()) :: String.t() | nil
    defp moduledoc(resource) do
      case Code.fetch_docs(resource) do
        {:docs_v1, _annotation, _beam_language, "text/markdown", %{"en" => doc}, _metadata, _docs} ->
          doc
          |> String.split("\n\n")
          |> List.first()
          |> String.replace(~r/\s+/, " ")
          |> String.trim()

        _docs ->
          nil
      end
    end

    @spec normalize_description(term()) :: String.t() | nil
    defp normalize_description(nil), do: nil

    defp normalize_description(description) when is_binary(description) do
      case String.trim(description) do
        "" -> nil
        description -> description
      end
    end

    defp normalize_description(_description), do: nil
  end
end
