with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Report.Ontology do
    @moduledoc """
    Ontology report: the domain vocabulary declared by the project's Ash
    resources — every entity (resource) and the terms it defines (attributes,
    calculations, aggregates, and relationships), with documentation coverage
    as the worklist of terms still missing a description.

    This is the generated equivalent of a hand-maintained data dictionary: the
    names, types, constraints, and descriptions are read from the code, so the
    table is always in sync. A hand-maintained ontology often carries a
    *Version* column; that isn't derivable from the code and is deliberately
    not reported here.
    """

    @behaviour Clarity.Report

    use Clarity.Web, :live_component

    import Clarity.Components.MarkdownComponent

    alias Ash.Resource.Info
    alias Ash.Resource.Relationships
    alias Clarity.Graph
    alias Clarity.Report.Charts
    alias Clarity.Vertex
    alias Clarity.Vertex.Ash.Aggregate
    alias Clarity.Vertex.Ash.Attribute
    alias Clarity.Vertex.Ash.Calculation
    alias Clarity.Vertex.Ash.Relationship
    alias Clarity.Vertex.Ash.Resource
    alias Clarity.Vertex.Ash.Type
    alias Clarity.Vertex.Util

    @kind_order [:attribute, :calculation, :aggregate, :relationship]

    @typep term_kind() :: :attribute | :calculation | :aggregate | :relationship

    @typep term_entry() :: %{
             required(:kind) => term_kind(),
             required(:name) => String.t(),
             required(:fqn) => String.t(),
             required(:id) => String.t(),
             required(:linked?) => boolean(),
             required(:type) => iodata(),
             required(:description) => String.t() | nil,
             required(:notes) => iodata()
           }

    @typep gap() :: %{required(:name) => String.t(), required(:private?) => boolean()}

    @typep entity() :: %{
             required(:name) => String.t(),
             required(:id) => String.t(),
             required(:domain) => String.t(),
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

    @impl Phoenix.LiveComponent
    def update(assigns, socket) do
      entities = entities(assigns.graph)

      {:ok,
       assign(socket,
         prefix: assigns.prefix,
         lens: assigns.lens,
         graph: assigns.graph,
         markdown: build_markdown(entities),
         dashboard: dashboard(entities)
       )}
    end

    @impl Phoenix.LiveComponent
    def render(assigns) do
      ~H"""
      <section class="space-y-6">
        <div class="space-y-4">
          <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
            <Charts.stat label="Entities" value={@dashboard.entities} />
            <Charts.stat label="Terms" value={@dashboard.terms} />
            <Charts.stat label="Documented" value={@dashboard.documented} tone={:ok} />
            <Charts.stat label="Undocumented" value={@dashboard.undocumented} tone={:warning} />
          </div>
          <Charts.stacked_bar title="Documentation coverage" segments={@dashboard.coverage} />
        </div>

        <.markdown
          content={@markdown}
          prefix={@prefix}
          lens={@lens}
          graph={@graph}
          class="max-w-[75ch]"
        />
      </section>
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
        id: Util.id(Resource, [resource]),
        domain: domain_name(resource),
        moduledoc: moduledoc(resource),
        data_layer: inspect(Info.data_layer(resource)),
        terms: terms(resource, linked_ids),
        undocumented: undocumented_terms(resource)
      }
    end

    # The dictionary lists public terms only; the documentation coverage
    # section below counts every undocumented term, private ones included.
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
            iodata(),
            String.t() | nil,
            iodata(),
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
        for(
          attribute <- Info.attributes(resource),
          undocumented?(attribute.description),
          do: attribute
        ),
        for(
          calculation <- Info.calculations(resource),
          undocumented?(calculation.description),
          do: calculation
        ),
        for(
          aggregate <- Info.aggregates(resource),
          undocumented?(aggregate.description),
          do: aggregate
        ),
        for(
          relationship <- Info.relationships(resource),
          undocumented?(relationship.description),
          do: relationship
        )
      ]
      |> Enum.concat()
      |> Enum.map(fn term ->
        %{
          name: Atom.to_string(term.name),
          private?: not Map.get(term, :public?, false)
        }
      end)
      |> Enum.sort_by(& &1.name)
    end

    @spec undocumented?(term()) :: boolean()
    defp undocumented?(nil), do: true

    defp undocumented?(description) when is_binary(description),
      do: String.trim(description) == ""

    defp undocumented?(_description), do: false

    # Markdown

    @spec build_markdown([entity()]) :: iodata()
    defp build_markdown([]) do
      "Clarity hasn't found any Ash resources, so there is no ontology to report.\n\n"
    end

    defp build_markdown(entities) do
      [
        intro(),
        entities_section(entities),
        terms_section(entities),
        coverage_section(entities)
      ]
    end

    @spec intro() :: iodata()
    defp intro do
      [
        "This report is the system's ontology — its vocabulary — generated from its Ash ",
        "resources instead of maintained by hand. Each **entity** is a ",
        "resource; each **term** is an attribute, calculation, aggregate, or relationship ",
        "it declares. Actions are deliberately left out: they are verbs, and this is a ",
        "dictionary of nouns.\n\n",
        "The dictionary lists *public* terms only — what a reader outside the code may ",
        "see. The documentation coverage at the bottom counts every term still missing ",
        "a description, private ones included, as a worklist for filling the gaps in. ",
        "A hand-maintained ontology often carries a *Version* column; that isn't ",
        "derivable from the code, so it is deliberately not reported here. A term's ",
        "`sensitive` flag is shown because a dictionary reader deserves to know — the ",
        "security posture report owns the deeper question of where sensitive data is ",
        "exposed.\n\n"
      ]
    end

    @spec entities_section([entity()]) :: iodata()
    defp entities_section(entities) do
      [
        "### Entities\n\n",
        "Each resource is an entity in the ontology, owned by its domain.\n\n",
        "| Domain | Entity | Description | Data layer |\n",
        "| --- | --- | --- | --- |\n",
        Enum.map(entities, &entity_row/1),
        "\n"
      ]
    end

    @spec entity_row(entity()) :: iodata()
    defp entity_row(entity) do
      [
        "| ",
        entity.domain,
        " | ",
        ["[", entity.name, "](vertex://", entity.id, ")"],
        " | ",
        cell(entity.moduledoc),
        " | ",
        entity.data_layer,
        " |\n"
      ]
    end

    @spec terms_section([entity()]) :: iodata()
    defp terms_section(entities) do
      [
        "### Terms\n\n",
        "The vocabulary each entity defines. A term's *Type* is the value it holds — for ",
        "a relationship it is written out as the sentence the relationship states, with ",
        "the cardinality in words. Custom types and embedded resources link through to ",
        "their own page: their vocabulary is part of the ontology too. An ⚠ marks a term ",
        "with no description.\n\n",
        Enum.flat_map(entities, fn entity ->
          [
            "#### `",
            entity.name,
            "`\n\n",
            "| Term | Kind | Type | Description | Notes |\n",
            "| --- | --- | --- | --- | --- |\n",
            Enum.map(entity.terms, &term_row/1),
            "\n"
          ]
        end)
      ]
    end

    @spec term_row(term_entry()) :: iodata()
    defp term_row(term) do
      [
        "| ",
        term_link(term),
        " | ",
        Atom.to_string(term.kind),
        " | ",
        term.type,
        " | ",
        description_cell(term.description),
        " | ",
        notes_cell(term.notes),
        " |\n"
      ]
    end

    @spec term_link(term_entry()) :: iodata()
    defp term_link(%{linked?: true} = term), do: ["[", term.fqn, "](vertex://", term.id, ")"]
    defp term_link(term), do: term.fqn

    @spec description_cell(String.t() | nil) :: iodata()
    defp description_cell(nil), do: ["⚠ ", cell(nil), " *(undocumented)*"]

    defp description_cell(description), do: cell(description)

    @spec notes_cell(iodata()) :: iodata()
    defp notes_cell([]), do: cell(nil)
    defp notes_cell(notes), do: notes

    @spec coverage_section([entity()]) :: iodata()
    defp coverage_section(entities) do
      terms = Enum.flat_map(entities, & &1.terms)
      total = length(terms)
      documented = Enum.count(terms, &(&1.description != nil))
      undocumented = total - documented

      [
        "### Documentation coverage\n\n",
        "The analogue of a hand-maintained ontology's *Status* column: ",
        Integer.to_string(documented),
        " of ",
        Integer.to_string(total),
        " public terms ",
        pluralize(total, "has", "have"),
        " a description; ",
        Integer.to_string(undocumented),
        " ",
        pluralize(undocumented, "is", "are"),
        " still undocumented, private terms included.\n\n",
        coverage_table(entities),
        worklist_section(entities)
      ]
    end

    @spec coverage_table([entity()]) :: iodata()
    defp coverage_table(entities) do
      [
        "| Entity | Public terms | Documented | Undocumented |\n",
        "| --- | --- | --- | --- |\n",
        Enum.map(entities, &coverage_row/1),
        "\n"
      ]
    end

    @spec coverage_row(entity()) :: iodata()
    defp coverage_row(entity) do
      total = length(entity.terms)
      documented = Enum.count(entity.terms, &(&1.description != nil))

      [
        "| ",
        ["[", entity.name, "](vertex://", entity.id, ")"],
        " | ",
        Integer.to_string(total),
        " | ",
        Integer.to_string(documented),
        " | ",
        Integer.to_string(total - documented),
        " |\n"
      ]
    end

    @spec worklist_section([entity()]) :: iodata()
    defp worklist_section(entities) do
      case Enum.reject(entities, &(&1.undocumented == [])) do
        [] ->
          "Every term has a description — the vocabulary is fully documented.\n\n"

        gaps ->
          [
            "Terms still missing a description:\n\n",
            Enum.map(gaps, fn entity ->
              [
                "- **",
                entity.name,
                "**: ",
                Enum.map_intersperse(entity.undocumented, ", ", &gap_name/1),
                "\n"
              ]
            end),
            "\n"
          ]
      end
    end

    @spec gap_name(gap()) :: iodata()
    defp gap_name(%{name: name, private?: true}), do: ["`", name, "` *(private)*"]
    defp gap_name(%{name: name}), do: ["`", name, "`"]

    # Dashboard

    @spec dashboard([entity()]) :: map()
    defp dashboard(entities) do
      terms = Enum.flat_map(entities, & &1.terms)
      total = length(terms)
      documented = Enum.count(terms, &(&1.description != nil))
      undocumented = total - documented

      %{
        entities: length(entities),
        terms: total,
        documented: documented,
        undocumented: undocumented,
        coverage: [
          %{label: "Documented", value: documented, tone: :ok},
          %{label: "Undocumented", value: undocumented, tone: :warning}
        ]
      }
    end

    # Term helpers

    @spec vertex_module(term_kind()) :: module()
    defp vertex_module(:attribute), do: Attribute
    defp vertex_module(:calculation), do: Calculation
    defp vertex_module(:aggregate), do: Aggregate
    defp vertex_module(:relationship), do: Relationship

    @spec kind_index(term_kind()) :: non_neg_integer() | nil
    defp kind_index(kind), do: Enum.find_index(@kind_order, &(&1 == kind))

    @spec attribute_notes(Ash.Resource.Attribute.t()) :: iodata()
    defp attribute_notes(attribute) do
      [
        if(attribute.primary_key?, do: "**primary key**"),
        if(attribute.sensitive?, do: "**sensitive**"),
        if(attribute.allow_nil? == false, do: "**required**"),
        one_of_notes(attribute.constraints)
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.intersperse(" · ")
    end

    @spec relationship_notes(Relationships.relationship()) :: iodata()
    defp relationship_notes(relationship) do
      if Map.get(relationship, :allow_nil?) == false, do: ["**required**"], else: []
    end

    # An atom type's `one_of` members are themselves vocabulary, so an enum's
    # values are spelled out (an array attribute's item vocabulary too).
    @spec one_of_notes(term()) :: iodata() | nil
    defp one_of_notes(constraints) do
      case constraint_members(constraints) do
        [] ->
          nil

        members ->
          [
            "one of ",
            Enum.map_intersperse(members, ", ", fn member -> ["`", inspect(member), "`"] end)
          ]
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

    @spec relationship_type(Relationships.relationship(), MapSet.t(String.t())) ::
            iodata()
    defp relationship_type(relationship, linked_ids) do
      [
        cardinality_phrase(relationship),
        destination_link(relationship.destination, linked_ids),
        through_suffix(relationship)
      ]
    end

    @spec cardinality_phrase(Relationships.relationship()) :: String.t()
    defp cardinality_phrase(%{type: :belongs_to}), do: "belongs to one "
    defp cardinality_phrase(%{type: :has_one}), do: "has one "
    defp cardinality_phrase(%{type: :has_many}), do: "has many "
    defp cardinality_phrase(%{type: :many_to_many}), do: "has many "

    @spec destination_link(module(), MapSet.t(String.t())) :: iodata()
    defp destination_link(destination, linked_ids) do
      id = Util.id(Resource, [destination])

      if MapSet.member?(linked_ids, id) do
        ["[", inspect(destination), "](vertex://", id, ")"]
      else
        ["`", inspect(destination), "`"]
      end
    end

    @spec through_suffix(Relationships.relationship()) :: iodata()
    defp through_suffix(%{type: :many_to_many, through: through}) do
      [" (through `", inspect(through), "`)"]
    end

    defp through_suffix(_relationship), do: []

    # A type links through to its `Vertex.Ash.Type` page when the graph has
    # one (custom types and embedded resources), so the vocabulary of the
    # value types stays part of the ontology.
    @spec format_type(term(), MapSet.t(String.t())) :: iodata()
    defp format_type({:array, inner_type}, linked_ids) do
      ["list of ", format_type(inner_type, linked_ids)]
    end

    defp format_type(type, linked_ids) when is_atom(type) do
      type_name =
        type
        |> to_string()
        |> String.replace_prefix("Elixir.", "")
        |> String.replace_prefix("Ash.Type.", "")

      id = Util.id(Type, [type])

      if MapSet.member?(linked_ids, id) do
        ["[", type_name, "](vertex://", id, ")"]
      else
        type_name
      end
    end

    defp format_type(type, _linked_ids), do: ["`", inspect(type), "`"]

    @spec domain_name(Ash.Resource.t()) :: String.t()
    defp domain_name(resource) do
      case Info.domain(resource) do
        nil -> "—"
        domain -> inspect(domain)
      end
    end

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

    defp normalize_description(description) when is_binary(description),
      do: String.trim(description)

    defp normalize_description(_description), do: nil

    # Free text into a single markdown table cell: escape pipes, collapse whitespace.
    @spec cell(String.t() | nil) :: String.t()
    defp cell(text) when text in [nil, ""], do: "—"

    defp cell(text) do
      text |> String.replace("|", "\\|") |> String.replace(~r/\s+/, " ") |> String.trim()
    end

    @spec pluralize(non_neg_integer(), String.t(), String.t()) :: String.t()
    defp pluralize(1, singular, _plural), do: singular
    defp pluralize(_count, _singular, plural), do: plural
  end
end
