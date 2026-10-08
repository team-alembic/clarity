defmodule Clarity.Autolink do
  @moduledoc """
  Links the names of vertices where rendered text mentions them, so a
  description such as "A single utterance inside a Conversation, from a User"
  links Conversation and User to their pages.

  A resource, domain or Reactor is named by its module
  (`Demo.Helpdesk.Conversation`), by its name within the application
  (`Helpdesk.Conversation`) and by its short name (`Conversation`, or
  `Accounts` for a domain), and a resource by its plural too
  (`Conversations`, `Policies`). An attribute, calculation, aggregate,
  relationship or action is named by its name (`total_cents`, `:status`,
  `sensitive?`) and by its resource's name and its own (`Invoice.total_cents`).
  Field names that read as plain words, such as `status`, link only in inline
  code; ones that look like code, such as `total_cents`, link in running text
  too.

  Optionally, running text links lowercase mentions as well: of resources and
  domains, word by word (`tickets`, `time entries`), written as the names
  they stand for (Tickets, TimeEntries), and of the fields of the resource
  the text is about (`reporter`, `time entries` for `time_entries`), as
  written.

  When a name fits more than one vertex, the text's own vertex settles it by
  nearness: its own resource first, then a resource it has a relationship to,
  then one in its domain. Of two as near, the one the name names wins over
  the one it pluralises (`Projects`, the domain, over the Project resource's
  plural); otherwise the name isn't linked. Text about a module is read as
  about the domain or resource the module defines.
  Only whole words link, each vertex at its first mention in a paragraph or
  table cell (or optionally at every mention), and never the vertex the text
  describes, nor text in a heading, a link or a code block.
  """

  alias Ash.Resource.Info
  alias Clarity.Graph
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Action
  alias Clarity.Vertex.Ash.Aggregate
  alias Clarity.Vertex.Ash.Attribute
  alias Clarity.Vertex.Ash.Calculation
  alias Clarity.Vertex.Ash.Domain
  alias Clarity.Vertex.Ash.Relationship
  alias Clarity.Vertex.Ash.Resource
  alias Clarity.Vertex.ModuleProvider

  @typedoc "Names that link, each to the vertex it names."
  @type names() :: %{String.t() => Vertex.t()}

  @typedoc "Every name the vertices of a graph go by, from `index/2`."
  @type index() :: %{
          graph: Graph.t(),
          spellings: [{String.t(), [{Vertex.t(), :name | :plural}]}],
          neighbours: %{optional(module()) => [module()]}
        }

  @typedoc """
  How text links names: at `every` mention rather than each paragraph's
  first, and `lowercase` mentions too. Both are off unless given.
  """
  @type options() :: [every: boolean(), lowercase: boolean()]

  # The text's vertex's own resource, the resources it relates to, and its domain.
  @typep context() :: %{
           resource: module() | nil,
           domain: module() | nil,
           distances: %{optional(module()) => non_neg_integer()}
         }

  @named_by_module [Resource, Domain, Vertex.Reactor]
  # Vertices for a resource's fields, with the key holding the field.
  @fields %{
    Attribute => :attribute,
    Calculation => :calculation,
    Aggregate => :aggregate,
    Relationship => :relationship,
    Action => :action
  }
  @linkable @named_by_module ++ Map.keys(@fields)

  # Anything in running text that could be a name, whole: a word or dotted
  # name, perhaps after a colon and before a ? or !, not part of a longer one.
  @token ~r/(?<![\w.:'’]):?[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*[?!]?/u
  # Text ending in a name's possessive: "Invoice's ".
  @possessive ~r/(?<![\w.])([A-Za-z][\w.]*)['’]s\s+$/u
  # The most words a lowercase name runs to ("sla policy", "time entries").
  @phrase_words 4

  # A URL or path, such as /app/projects/new: any run of text with a slash.
  # Its words are never linked, nor written otherwise.
  @url ~r{[^\s]*/[^\s]*}u

  @doc """
  Returns the names to link in text about `vertex` (or about nothing in
  particular, with `nil`), from the vertices in `graph`.

  With `lowercase: true`, resources and domains are named in lowercase too,
  word by word: `ticket`, `tickets`, `time entries`, `billing`.
  """
  @spec names(Graph.t(), Vertex.t() | nil, keyword()) :: names()
  def names(graph, vertex, opts \\ []), do: graph |> index(opts) |> names_in(vertex)

  @doc """
  Gathers every name the vertices in `graph` go by, once, so that
  `names_in/2` can settle them for text about one vertex after another.
  Takes `lowercase:` as `names/3` does.
  """
  @spec index(Graph.t(), keyword()) :: index()
  def index(graph, opts \\ []) do
    lowercase? = Keyword.get(opts, :lowercase, false)

    spellings =
      graph
      |> Graph.vertices({:in, :vertex_type, @linkable})
      |> Enum.flat_map(fn named ->
        Enum.map(forms(named, lowercase?), fn {name, form} -> {name, {named, form}} end)
      end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Enum.map(fn {name, candidates} -> {name, Enum.uniq(candidates)} end)

    %{graph: graph, spellings: spellings, neighbours: neighbours(graph)}
  end

  @doc """
  Returns the names to link in text about `vertex`, as `names/3` does, from
  an `index/2`.
  """
  @spec names_in(index(), Vertex.t() | nil) :: names()
  def names_in(%{spellings: spellings, neighbours: neighbours}, vertex) do
    context = vertex |> context() |> with_distances(neighbours)

    spellings
    |> Enum.flat_map(fn {name, candidates} ->
      candidates
      |> Enum.reject(fn {named, _form} -> described?(named, vertex) end)
      |> pick(context)
      |> case do
        nil -> []
        named -> [{name, named}]
      end
    end)
    |> Map.new()
  end

  @doc """
  Links the first mention of each name in an MDEx document, to the path
  `path` gives for its vertex.

  With `every: true`, every mention links, not only each paragraph's or
  table cell's first.

  With `lowercase: true`, and names from `names/3` with the same, running
  text links lowercase mentions too: of a resource or domain, written as the
  name it stands for ("time entries" as TimeEntries), and of a field of the
  resource the text is about (`vertex:`), as written ("reporter").

  Given the `index:` the names came from, text under a heading that links a
  resource, domain or field (by a `vertex://` link), until the next heading
  as high, is about that vertex instead, and so is a table row that links
  one: the Projects domain's section of an overview prefers the Projects
  domain's Ticket.
  """
  @spec link(MDEx.Document.t(), names(), (Vertex.t() -> String.t()), keyword()) ::
          MDEx.Document.t()
  def link(document, names, path, opts \\ []) do
    lowercase? = Keyword.get(opts, :lowercase, false)

    context = %{
      names: names,
      path: path,
      every?: Keyword.get(opts, :every, false),
      lowercase?: lowercase?,
      resource: resource_of(Keyword.get(opts, :vertex), lowercase?),
      index: Keyword.get(opts, :index)
    }

    {document, _linked} = walk(document, context, MapSet.new())
    document
  end

  @doc """
  Returns nodes that wrap `children` in a link LiveView follows by patching.
  """
  @spec patch_link(String.t(), [MDEx.Document.md_node()], String.t() | nil) ::
          [MDEx.Document.md_node()]
  def patch_link(url, children, title \\ nil) do
    title_attr = if title in [nil, ""], do: "", else: ~s( title="#{escape(title)}")

    # MDEx.Link has no attributes field, so the anchor is raw HTML.
    open = %MDEx.Raw{
      literal:
        ~s(<a href="#{escape(url)}" data-phx-link="patch" data-phx-link-state="push"#{title_attr}>)
    }

    [open | children] ++ [%MDEx.Raw{literal: "</a>"}]
  end

  # Whether `named` is what the text describes: its own vertex, or for text
  # about a module, the domain, resource or Reactor the module defines.
  @spec described?(Vertex.t(), Vertex.t() | nil) :: boolean()
  defp described?(named, named), do: true

  defp described?(%{__struct__: struct} = named, %Vertex.Module{module: module})
       when struct in @named_by_module,
       do: ModuleProvider.module(named) == module

  defp described?(_named, _vertex), do: false

  @spec walk(node, map(), MapSet.t()) :: {node, MapSet.t()}
        when node: MDEx.Document.t() | MDEx.Document.md_node()
  defp walk(%MDEx.Link{} = node, _context, linked), do: {node, linked}
  defp walk(%MDEx.Heading{} = node, _context, linked), do: {node, linked}

  # Under a heading about a vertex, text is about it until a heading as high.
  defp walk(%MDEx.Document{nodes: nodes} = document, context, linked) do
    {nodes, {_sections, linked}} =
      Enum.map_reduce(nodes, {[{0, context}], linked}, fn
        %MDEx.Heading{level: level} = heading, {sections, linked} ->
          sections = Enum.drop_while(sections, fn {above, _context} -> above >= level end)
          [{_level, outer} | _] = sections

          case subject(heading, outer) do
            nil -> {heading, {sections, linked}}
            inner -> {heading, {[{level, inner} | sections], linked}}
          end

        node, {[{_level, context} | _] = sections, linked} ->
          {node, linked} = walk(node, context, linked)
          {node, {sections, linked}}
      end)

    {%{document | nodes: nodes}, linked}
  end

  # A table row about a vertex is about it.
  defp walk(%MDEx.TableRow{nodes: cells} = row, context, linked) do
    {cells, linked} = children(cells, subject(row, context) || context, linked)
    {%{row | nodes: cells}, linked}
  end

  # Each paragraph or table cell links its own first mentions.
  defp walk(%block{nodes: nodes} = node, context, linked)
       when block in [MDEx.Paragraph, MDEx.TableCell] do
    {nodes, _linked} = children(nodes, context, MapSet.new())
    {%{node | nodes: nodes}, linked}
  end

  defp walk(%{nodes: nodes} = node, context, linked) when is_list(nodes) do
    {nodes, linked} = children(nodes, context, linked)
    {%{node | nodes: nodes}, linked}
  end

  defp walk(node, _context, linked), do: {node, linked}

  # The context for text about the resource, domain or field that `node`
  # links first, if it links one and there's an index to name things from.
  @spec subject(MDEx.Document.md_node(), map()) :: map() | nil
  defp subject(_node, %{index: nil}), do: nil

  defp subject(node, context) do
    with "vertex://" <> path <- first_vertex_link(node),
         [id | _rest] = String.split(path, "/"),
         %{__struct__: struct} = vertex
         when struct in [Resource, Domain] or is_map_key(@fields, struct) <-
           Graph.get_vertex(context.index.graph, id) do
      %{
        context
        | names: names_in(context.index, vertex),
          resource: resource_of(vertex, context.lowercase?)
      }
    else
      _no_subject -> nil
    end
  end

  @spec first_vertex_link(MDEx.Document.md_node()) :: String.t() | nil
  defp first_vertex_link(%MDEx.Link{url: "vertex://" <> _path = url}), do: url

  defp first_vertex_link(%{nodes: nodes}) when is_list(nodes),
    do: Enum.find_value(nodes, &first_vertex_link/1)

  defp first_vertex_link(_node), do: nil

  # The resource whose fields lowercase text links: the one text about
  # `vertex` is about.
  @spec resource_of(Vertex.t() | nil, boolean()) :: module() | nil
  defp resource_of(_vertex, false), do: nil
  defp resource_of(vertex, true), do: context(vertex).resource

  # Each child, with the name whose possessive the text before it ends in.
  @spec children([MDEx.Document.md_node()], map(), MapSet.t()) ::
          {[MDEx.Document.md_node()], MapSet.t()}
  defp children(nodes, context, linked) do
    nodes
    |> Enum.zip([nil | nodes])
    |> Enum.flat_map_reduce(linked, fn {node, previous}, linked ->
      owner =
        with %MDEx.Text{literal: text} <- previous,
             [_, name] <- Regex.run(@possessive, text) do
          name
        else
          _no_possessive -> nil
        end

      child(node, owner, context, linked)
    end)
  end

  @spec child(MDEx.Document.md_node(), String.t() | nil, map(), MapSet.t()) ::
          {[MDEx.Document.md_node()], MapSet.t()}
  defp child(%MDEx.Text{literal: text}, _owner, context, linked) do
    # Alternates prose and URLs, starting and ending with prose.
    @url
    |> Regex.split(text, include_captures: true)
    |> Enum.chunk_every(2)
    |> Enum.flat_map_reduce(linked, fn chunk, linked ->
      [prose | url] = chunk
      # Alternates text and tokens, starting and ending with text.
      {nodes, linked} =
        @token |> Regex.split(prose, include_captures: true) |> scan(nil, context, linked)

      {nodes ++ Enum.flat_map(url, &text_nodes/1), linked}
    end)
  end

  defp child(%MDEx.Code{literal: literal} = code, owner, context, linked) do
    case owned(owner, literal, context) do
      nil -> mention(literal, [code], context, linked)
      vertex -> link_vertex(vertex, [code], context, linked)
    end
  end

  defp child(node, _owner, context, linked) do
    {node, linked} = walk(node, context, linked)
    {[node], linked}
  end

  # Links the tokens in `pieces`, alternately text and token, each knowing the
  # token before it, whose possessive it may follow. In lowercase, a token
  # runs on into the next few when together they spell a name.
  @spec scan([String.t()], String.t() | nil, map(), MapSet.t()) ::
          {[MDEx.Document.md_node()], MapSet.t()}
  defp scan([text], _previous, _context, linked), do: {text_nodes(text), linked}

  defp scan([text, token | rest], previous, context, linked) do
    owner = if previous != nil and String.match?(text, ~r/^['’]s\s+$/u), do: previous
    {token, rest} = phrase(token, rest, context)
    {nodes, linked} = token(token, owner, context, linked)
    {more, linked} = scan(rest, token, context, linked)
    {text_nodes(text) ++ nodes ++ more, linked}
  end

  @spec text_nodes(String.t()) :: [MDEx.Document.md_node()]
  defp text_nodes(""), do: []
  defp text_nodes(text), do: [%MDEx.Text{literal: text}]

  # The longest name, of words a space apart, that starts at `token`, and the
  # pieces after it.
  @spec phrase(String.t(), [String.t()], map()) :: {String.t(), [String.t()]}
  defp phrase(token, rest, %{names: names}) do
    Enum.find_value((@phrase_words - 1)..1//-1, {token, rest}, fn more ->
      {run, after_run} = Enum.split(rest, 2 * more)
      phrase = Enum.join([token | Enum.take_every(tl(run), 2)], " ")

      if length(run) == 2 * more and Enum.all?(Enum.take_every(run, 2), &(&1 == " ")) and
           Map.has_key?(names, phrase),
         do: {phrase, after_run}
    end)
  end

  # "Invoice's total_cents": a field named after its resource's possessive is
  # that resource's, however near another resource's is, and links even when
  # its name is a plain word ("Invoice's status").
  @spec owned(String.t() | nil, String.t(), map()) :: Vertex.t() | nil
  defp owned(nil, _field, _context), do: nil

  defp owned(owner, field, context) do
    case Map.get(context.names, owner) do
      %{__struct__: Resource, resource: resource} ->
        Map.get(context.names, inspect(resource) <> "." <> String.trim_leading(field, ":"))

      _not_a_resource ->
        nil
    end
  end

  # Links a token of running text that names a vertex. A name may end in ? or
  # ! (sensitive?), so a token ending in one is tried with it, then without.
  @spec token(String.t(), String.t() | nil, map(), MapSet.t()) ::
          {[MDEx.Document.md_node()], MapSet.t()}
  defp token(text, owner, context, linked) do
    trimmed = text |> String.trim_trailing("?") |> String.trim_trailing("!")

    cond do
      vertex = owned(owner, text, context) ->
        link_vertex(vertex, [%MDEx.Text{literal: text}], context, linked)

      found = in_text(text, context) ->
        link_found(found, text, context, linked)

      found = trimmed != text && in_text(trimmed, context) ->
        {nodes, linked} = link_found(found, trimmed, context, linked)
        {nodes ++ [%MDEx.Text{literal: String.replace_prefix(text, trimmed, "")}], linked}

      true ->
        {[%MDEx.Text{literal: text}], linked}
    end
  end

  # The vertex a mention in running text names, and how to write its link.
  @spec in_text(String.t(), map()) :: {Vertex.t(), String.t()} | nil
  defp in_text(text, context) do
    with vertex when vertex != nil <- Map.get(context.names, text) do
      cond do
        prose?(text) -> {vertex, text}
        context.lowercase? -> lowercase_mention(vertex, text, context)
        true -> nil
      end
    end
  end

  # A lowercase mention of a resource or domain is written as the name it
  # stands for; one of the text's own resource's fields, as written.
  @spec lowercase_mention(Vertex.t(), String.t(), map()) :: {Vertex.t(), String.t()} | nil
  defp lowercase_mention(%{__struct__: struct} = vertex, text, _context)
       when struct in [Resource, Domain] do
    written =
      Enum.find_value(prose_forms(vertex), text, fn {name, _form} ->
        if lowercase(name) == text, do: name
      end)

    {vertex, written}
  end

  defp lowercase_mention(%{resource: resource} = vertex, text, %{resource: resource})
       when resource != nil,
       do: {vertex, text}

  defp lowercase_mention(_vertex, _text, _context), do: nil

  # Links a mention written `written`, or leaves `text` be if its vertex is
  # already linked.
  @spec link_found({Vertex.t(), String.t()}, String.t(), map(), MapSet.t()) ::
          {[MDEx.Document.md_node()], MapSet.t()}
  defp link_found({vertex, written}, text, context, linked) do
    if linked?(vertex, context, linked),
      do: {[%MDEx.Text{literal: text}], linked},
      else: link_vertex(vertex, [%MDEx.Text{literal: written}], context, linked)
  end

  # Links `nodes` if `text` names a vertex not yet linked, or leaves them be.
  @spec mention(String.t(), [MDEx.Document.md_node()], map(), MapSet.t()) ::
          {[MDEx.Document.md_node()], MapSet.t()}
  defp mention(text, nodes, context, linked) do
    case Map.fetch(context.names, text) do
      {:ok, vertex} -> link_vertex(vertex, nodes, context, linked)
      :error -> {nodes, linked}
    end
  end

  @spec link_vertex(Vertex.t(), [MDEx.Document.md_node()], map(), MapSet.t()) ::
          {[MDEx.Document.md_node()], MapSet.t()}
  defp link_vertex(vertex, nodes, context, linked) do
    if linked?(vertex, context, linked),
      do: {nodes, linked},
      else: {patch_link(context.path.(vertex), nodes), MapSet.put(linked, vertex)}
  end

  # Whether `vertex` is already linked, so its mention stays plain text,
  # unless every mention links.
  @spec linked?(Vertex.t(), map(), MapSet.t()) :: boolean()
  defp linked?(_vertex, %{every?: true}, _linked), do: false
  defp linked?(vertex, _context, linked), do: MapSet.member?(linked, vertex)

  # Names that read as names in running text: module-like ones, and field
  # names that look like code. Plain words, such as `status`, link only in
  # inline code.
  @spec prose?(String.t()) :: boolean()
  defp prose?(name), do: String.match?(name, ~r/^[A-Z]|^:|_|[?!]$/)

  # Each name a vertex goes by, as its own or as a plural, and in lowercase,
  # word by word, as running text writes them ("time entries").
  @spec forms(Vertex.t(), boolean()) :: [{String.t(), :name | :plural}]
  defp forms(vertex, lowercase?) do
    forms = Enum.uniq(Enum.map(spellings(vertex), &{&1, :name}) ++ prose_forms(vertex))

    if lowercase?,
      do:
        forms ++
          Enum.map(prose_forms(vertex) ++ field_forms(vertex), fn {name, form} ->
            {lowercase(name), form}
          end),
      else: forms
  end

  # The names prose writes a resource or domain by: its short name, a
  # resource's plural, and either after its domain's ("Helpdesk Ticket").
  @spec prose_forms(Vertex.t()) :: [{String.t(), :name | :plural}]
  defp prose_forms(%Resource{resource: resource} = vertex) do
    own = [{short(vertex), :name} | Enum.map(plurals(vertex), &{&1, :plural})]

    case domain(resource) do
      nil ->
        own

      domain ->
        domain_name = domain |> Module.split() |> List.last()
        own ++ Enum.map(own, fn {name, form} -> {domain_name <> " " <> name, form} end)
    end
  end

  defp prose_forms(%Domain{} = vertex), do: [{short(vertex), :name}]
  defp prose_forms(_vertex), do: []

  # A field's name of several words, which lowercase text writes apart
  # ("time entries" for time_entries).
  @spec field_forms(Vertex.t()) :: [{String.t(), :name}]
  defp field_forms(%{__struct__: struct} = vertex) when is_map_key(@fields, struct) do
    name = field_name(vertex)
    if String.contains?(name, "_"), do: [{name, :name}], else: []
  end

  defp field_forms(_vertex), do: []

  @spec field_name(Vertex.t()) :: String.t()
  defp field_name(%{__struct__: struct} = vertex),
    do: vertex |> Map.fetch!(Map.fetch!(@fields, struct)) |> Map.fetch!(:name) |> Atom.to_string()

  # A name in lowercase words: "time entries" for TimeEntries or time_entries,
  # "helpdesk ticket" for Helpdesk Ticket.
  @spec lowercase(String.t()) :: String.t()
  defp lowercase(name) do
    name
    |> String.split(" ")
    |> Enum.map_join(" ", &(&1 |> Macro.underscore() |> String.replace("_", " ")))
  end

  @spec short(Vertex.t()) :: String.t()
  defp short(vertex), do: vertex |> ModuleProvider.module() |> Module.split() |> List.last()

  @spec spellings(Vertex.t()) :: [String.t()]
  defp spellings(%{__struct__: struct, resource: resource} = vertex)
       when is_map_key(@fields, struct) do
    name = field_name(vertex)

    owners =
      Enum.uniq([
        resource |> Module.split() |> List.last(),
        Vertex.Name.in_app(resource),
        inspect(resource)
      ])

    [name, ":" <> name | Enum.map(owners, &(&1 <> "." <> name))]
  end

  defp spellings(vertex) do
    parts = vertex |> ModuleProvider.module() |> Module.split()

    in_app =
      case parts do
        [_app | [_, _ | _] = rest] -> [Enum.join(rest, ".")]
        _parts -> []
      end

    Enum.uniq([Enum.join(parts, ".") | in_app] ++ [List.last(parts)])
  end

  # The English plural of a resource's short name, by its last word:
  # Policies, Addresses, LineItems.
  @spec plurals(Vertex.t()) :: [String.t()]
  defp plurals(%Resource{} = vertex) do
    name = short(vertex)

    cond do
      String.match?(name, ~r/[^aeiou]y$/) -> [String.slice(name, 0..-2//1) <> "ies"]
      String.match?(name, ~r/(s|x|z|ch|sh)$/) -> [name <> "es"]
      true -> [name <> "s"]
    end
  end

  # The vertex a name fits, if it fits only one, or one ranks above the rest:
  # a field of the text's own resource; then a resource, domain or Reactor
  # before another resource's field ("user" the resource, not a
  # relationship of the same name); then the nearest (see rank/2); then the
  # one the name names rather than pluralises (the Projects domain, not the
  # Project resource's plural).
  @spec pick([{Vertex.t(), :name | :plural}], context()) :: Vertex.t() | nil
  defp pick([], _context), do: nil
  defp pick([{vertex, _form}], _context), do: vertex

  defp pick(candidates, context) do
    candidates
    |> Enum.group_by(
      fn {vertex, form} ->
        rank = rank(vertex, context)
        {rank != {0, 0}, Map.has_key?(@fields, vertex.__struct__), rank, form}
      end,
      &elem(&1, 0)
    )
    |> Enum.min_by(&elem(&1, 0))
    |> case do
      {_rank, [vertex]} -> vertex
      _tied -> nil
    end
  end

  # How near a vertex is to the text: the text's own resource, or one of its
  # fields; then, in the text's domain and after that outside it, the fewest
  # relationships away from the text's resource (or its domain's nearest).
  @spec rank(Vertex.t(), context()) :: {0 | 1 | 2, non_neg_integer() | :infinity}
  defp rank(vertex, context) do
    home = home(vertex)
    distance = if home == nil, do: :infinity, else: Map.get(context.distances, home, :infinity)

    cond do
      home != nil and home == context.resource -> {0, 0}
      context.domain != nil and domain_of(vertex) == context.domain -> {1, distance}
      true -> {2, distance}
    end
  end

  # The resource a vertex is, or is a field of.
  @spec home(Vertex.t()) :: module() | nil
  defp home(%{resource: resource}), do: resource
  defp home(_vertex), do: nil

  @spec domain_of(Vertex.t()) :: module() | nil
  defp domain_of(%{__struct__: Domain, domain: domain}), do: domain
  defp domain_of(vertex), do: vertex |> home() |> domain()

  if Code.ensure_loaded?(Ash) do
    # Text about a resource or its field, or about a domain, resource or
    # module that is one, is read in its light.
    @spec context(Vertex.t() | nil) :: context()
    defp context(nil), do: about(nil)

    defp context(%{resource: resource}) when is_atom(resource) and resource != nil,
      do: about(resource)

    defp context(vertex), do: vertex |> ModuleProvider.module() |> about()

    @spec about(module() | nil) :: context()
    defp about(module) when is_atom(module) and module != nil do
      cond do
        Info.resource?(module) -> %{resource: module, domain: Info.domain(module), distances: %{}}
        Spark.Dsl.is?(module, Ash.Domain) -> %{resource: nil, domain: module, distances: %{}}
        true -> about(nil)
      end
    end

    defp about(_module), do: %{resource: nil, domain: nil, distances: %{}}

    # How many relationships apart each resource is from the text's
    # resource, or from the nearest of its domain's resources, going along
    # relationships either way.
    @spec with_distances(context(), %{module() => [module()]}) :: context()
    defp with_distances(context, neighbours) do
      sources =
        cond do
          context.resource != nil -> [context.resource]
          context.domain != nil -> Ash.Domain.Info.resources(context.domain)
          true -> []
        end

      distances = spread(sources, neighbours, Map.new(sources, &{&1, 0}), 0)
      %{context | distances: distances}
    end

    # Each resource's neighbours: those it has a relationship to, and those
    # with one to it.
    @spec neighbours(Graph.t()) :: %{module() => [module()]}
    defp neighbours(graph) do
      for %Resource{resource: resource} <- Graph.vertices(graph, {:==, :vertex_type, Resource}),
          %{destination: destination} <- Info.relationships(resource),
          {from, to} <- [{resource, destination}, {destination, resource}],
          reduce: %{} do
        neighbours -> Map.update(neighbours, from, [to], &[to | &1])
      end
    end

    # Breadth first, out from `frontier`, `distance` relationships away.
    @spec spread([module()], %{module() => [module()]}, map(), non_neg_integer()) ::
            %{module() => non_neg_integer()}
    defp spread([], _neighbours, distances, _distance), do: distances

    defp spread(frontier, neighbours, distances, distance) do
      next =
        frontier
        |> Enum.flat_map(&Map.get(neighbours, &1, []))
        |> Enum.uniq()
        |> Enum.reject(&Map.has_key?(distances, &1))

      spread(
        next,
        neighbours,
        Map.merge(distances, Map.new(next, &{&1, distance + 1})),
        distance + 1
      )
    end

    @spec domain(module() | nil) :: module() | nil
    defp domain(nil), do: nil

    defp domain(module) do
      if Info.resource?(module), do: Info.domain(module)
    end
  else
    @spec context(Vertex.t() | nil) :: context()
    defp context(_vertex), do: %{resource: nil, domain: nil, distances: %{}}

    @spec with_distances(context(), %{module() => [module()]}) :: context()
    defp with_distances(context, _neighbours), do: context

    @spec neighbours(Graph.t()) :: %{module() => [module()]}
    defp neighbours(_graph), do: %{}

    @spec domain(module() | nil) :: module() | nil
    defp domain(_module), do: nil
  end

  # Escapes values spliced into raw HTML.
  @spec escape(String.t()) :: String.t()
  defp escape(value), do: value |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
end
